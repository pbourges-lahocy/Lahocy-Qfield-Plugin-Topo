package fr.lahocy.topolink

import android.annotation.SuppressLint
import android.bluetooth.BluetoothSocket
import android.content.Context
import org.json.JSONObject
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.util.Locale
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

/**
 * Pilote Leica GeoCOM (protocole ASCII) sur Bluetooth SPP : TS13 / TS16 / TS60 / Viva.
 * Portage ligne à ligne de bridge/drivers/geocom.py.
 *
 * Requête  "%R1Q,<rpc>:<p1>,<p2>...\r\n"
 * Réponse  "%R1P,0,<tr>:<rc>,<v1>,<v2>...\r\n"   (rc = 0 : OK)
 * Angles GeoCOM en radians -> grades ; distances en mètres.
 */
class GeoComError(message: String) : RuntimeException(message)

@SuppressLint("MissingPermission")
class GeoComDriver(private val ctx: Context, private val target: String, events: EventBus) : TpsDriver(events) {
    override val name = "geocom"

    companion object {
        const val COM_NullProc = 0
        const val CSV_GetInstrumentName = 5004
        const val CSV_CheckPower = 5039
        const val TMC_GetAngle5 = 2107
        const val TMC_SetOrientation = 2113
        const val TMC_SetInclineSwitch = 2006
        const val BAP_MeasDistanceAngle = 17017
        const val BAP_SetTargetType = 17021
        const val BAP_SetPrismType = 17008
        const val AUT_MakePositioning = 9037
        const val AUT_Search = 9029
        const val AUT_LockIn = 9013
        const val AUT_PS_EnableRange = 9048
        const val AUT_PS_SetRange = 9047
        const val AUT_PS_SearchNext = 9051
        const val AUS_SetUserAtrState = 18005
        const val AUS_SetUserLockState = 18007
        const val MOT_ReadLockStatus = 6021
        const val MOT_StartController = 6001
        const val MOT_SetVelocity = 6004
        const val MOT_StopController = 6002
        const val EDM_Laserpointer = 1004

        const val BAP_DEF_DIST = 2
        const val BAP_REFL_USE = 0
        const val BAP_REFL_LESS = 1
        const val TMC_AUTO_INC = 1

        /** Codes retour TMC qui sont des avertissements : les valeurs renvoyées restent utilisables. */
        val TMC_WARNINGS = mapOf(
            1280 to "mesure sans correction complète",
            1281 to "précision non garantie",
            1282 to "angles seuls valides (pas de distance)",
            1283 to "angles seuls valides, sans correction complète (instrument calé ?)",
            1284 to "angles seuls valides, précision non garantie"
        )
        /** Angles seuls : pas de distance dans la réponse. */
        val TMC_ANGLE_ONLY = setOf(1282, 1283, 1284)

        val ERRORS = mapOf(
            2 to "paramètre invalide", 5 to "fonction non implémentée sur cet instrument", 6 to "délai dépassé",
            9 to "commande interrompue", 12 to "fonction indisponible (licence GeoCOM ?)",
            1285 to "pas de mesure d'angle (instrument calé, compensateur ?)", 1286 to "PPM erroné",
            1287 to "distance non mesurée", 1288 to "instrument occupé", 1289 to "pas de signal (prisme visé ?)",
            8704 to "délai ATR dépassé", 8710 to "aucune cible trouvée", 8711 to "plusieurs cibles",
            8712 to "environnement défavorable (lumière, reflets)", 8714 to "ATR / verrouillage non activé",
            8716 to "précision ATR insuffisante", 8720 to "hors zone de travail",
            1792 to "moteur non prêt", 1793 to "moteur occupé", 1794 to "contrôleur moteur non démarré"
        )

        val PRISM_TYPES = mapOf(
            "round" to 0, "mini" to 1, "tape" to 2, "360" to 3, "user1" to 4, "user2" to 5, "user3" to 6,
            "mini360" to 7, "miniZero" to 8, "user" to 9, "ndsTape" to 10, "grz121" to 11, "maMPR122" to 12, "standard" to 0
        )
    }

    private var socket: BluetoothSocket? = null
    private var out: OutputStream? = null
    private val lines = LinkedBlockingQueue<String>()
    private val ioLock = Any()
    private var laser = false
    private var reflectorless = false
    private var joystickRunning = false
    private var batteryTime = 0L
    /** Lectures consécutives « non verrouillé » : le verrouillage n'est déclaré perdu qu'après 3 (1,5 s). */
    private var unlockedReads = 0
    var deviceName: String = ""
        private set
    /** Dernier avertissement TMC (1280…1284), vide si la dernière lecture était propre. */
    @Volatile var lastWarning = ""
        private set

    // ------------------------------------------------------------------ bas niveau
    override fun connect() {
        val dev = BluetoothHelper.findDevice(ctx, target)
            ?: throw GeoComError(
                if (target.isBlank()) "aucune station choisie (appairer la station puis la sélectionner dans Lahocy Topo Link)"
                else "station Bluetooth introuvable : $target (appairée ?)"
            )
        deviceName = BluetoothHelper.nameOf(dev)
        AppLog.d("GeoCOM : connexion à $deviceName (${dev.address})")
        BluetoothHelper.adapter(ctx)?.cancelDiscovery()
        val s = dev.createRfcommSocketToServiceRecord(BluetoothHelper.SPP_UUID)
        try {
            s.connect()
        } catch (e: IOException) {
            try { s.close() } catch (ignored: IOException) {}
            throw GeoComError("connexion Bluetooth refusée par $deviceName : ${e.message} (station allumée, mode GeoCOM / Bluetooth actif ?)")
        }
        socket = s
        out = s.outputStream
        lines.clear()
        thread(isDaemon = true, name = "geocom-reader") { readLoop(s.inputStream) }
        Thread.sleep(200)
        request(COM_NullProc, emptyList())
        model = try {
            val (_, vals) = request(CSV_GetInstrumentName, emptyList())
            val n = vals.firstOrNull()?.trim('"') ?: ""
            if (n.isBlank()) "Leica GeoCOM" else n
        } catch (e: Exception) {
            "Leica GeoCOM"
        }
        connected = true
        lastError = ""
        AppLog.d("GeoCOM : instrument $model")
        poll()
    }

    override fun disconnect() {
        val wasConnected = connected
        connected = false
        try { socket?.close() } catch (ignored: IOException) {}
        socket = null
        out = null
        if (wasConnected) AppLog.d("GeoCOM : déconnecté")
    }

    private fun readLoop(input: InputStream) {
        val buf = ByteArray(1024)
        val sb = StringBuilder()
        try {
            while (true) {
                val n = input.read(buf)
                if (n < 0) break
                for (i in 0 until n) {
                    val c = (buf[i].toInt() and 0xff).toChar()
                    if (c == '\n') {
                        val line = sb.toString().trim()
                        sb.setLength(0)
                        if (line.isNotEmpty()) lines.offer(line)
                    } else if (c != '\r') {
                        sb.append(c)
                    }
                }
            }
        } catch (ignored: IOException) {
        }
        if (connected) {
            connected = false
            lastError = "liaison Bluetooth perdue"
            AppLog.e("GeoCOM : liaison Bluetooth perdue")
            events.push("tps_disconnected", JSONObject().put("error", lastError))
        }
    }

    private fun fmt(p: Any): String = when (p) {
        is Double -> String.format(Locale.US, "%.8f", p)
        is Float -> String.format(Locale.US, "%.8f", p)
        else -> p.toString()
    }

    /** Envoie une requête GeoCOM et renvoie (rc, valeurs). */
    fun request(rpc: Int, params: List<Any>, timeoutMs: Long = 8000): Pair<Int, List<String>> {
        val o = out ?: throw GeoComError("port fermé")
        synchronized(ioLock) {
            val t0 = System.currentTimeMillis()
            lines.clear()
            val line = "%R1Q,$rpc:" + params.joinToString(",") { fmt(it) } + "\r\n"
            try {
                o.write(line.toByteArray(Charsets.US_ASCII))
                o.flush()
            } catch (e: IOException) {
                throw GeoComError("écriture impossible : ${e.message}")
            }
            var raw: String
            while (true) {
                raw = lines.poll(timeoutMs, TimeUnit.MILLISECONDS)
                    ?: throw GeoComError("pas de réponse de la station (${timeoutMs / 1000} s) : mode GeoCOM actif ?")
                if (raw.startsWith("%R1P")) break
                if (System.currentTimeMillis() - t0 > timeoutMs) throw GeoComError("réponse invalide : $raw")
            }
            latencyMs = (System.currentTimeMillis() - t0).toInt()
            val tail = raw.substringAfter(":", "")
            val parts = tail.split(",")
            val rc = parts[0].trim().toIntOrNull() ?: throw GeoComError("réponse invalide : $raw")
            return Pair(rc, parts.drop(1).map { it.trim() })
        }
    }

    private fun check(rc: Int, what: String) {
        if (rc != 0) {
            val label = ERRORS[rc] ?: TMC_WARNINGS[rc]
            lastError = "$what : code GeoCOM $rc" + (if (label != null) " ($label)" else "")
            throw GeoComError(lastError)
        }
    }

    /** Comme check(), mais accepte les avertissements TMC (valeurs utilisables). */
    private fun checkTmc(rc: Int, what: String, needDistance: Boolean) {
        if (rc == 0) { lastWarning = ""; return }
        val warn = TMC_WARNINGS[rc]
        if (warn != null && !(needDistance && rc in TMC_ANGLE_ONLY)) {
            lastWarning = warn
            AppLog.d("GeoCOM : $what : avertissement $rc ($warn)")
            return
        }
        check(rc, what)
    }

    // ------------------------------------------------------------------ configuration
    override fun setup(state: JSONObject) {
        val prism = PRISM_TYPES[state.str("prism", "standard")] ?: 0
        val atr = state.optBoolean("atr", true)
        try {
            request(BAP_SetPrismType, listOf(prism))
            request(AUS_SetUserAtrState, listOf(if (atr) 1 else 0))
            // Mode « lock » de l'ATR : sans lui, AUT_LockIn échoue (8714) et la station
            // ne suit pas le prisme même après une recherche réussie.
            request(AUS_SetUserLockState, listOf(if (atr) 1 else 0))
            request(TMC_SetInclineSwitch, listOf(1))
        } catch (e: GeoComError) {
            lastError = e.message ?: ""
        }
    }

    /** Verrouille sur le prisme visé ; active le mode lock si l'instrument le réclame. */
    private fun lockIn(): Boolean {
        var (rc, _) = request(AUT_LockIn, emptyList(), 10000)
        if (rc == 8714) {
            request(AUS_SetUserLockState, listOf(1))
            rc = request(AUT_LockIn, emptyList(), 10000).first
        }
        if (rc != 0) AppLog.d("GeoCOM : verrouillage refusé, code $rc (${ERRORS[rc] ?: "?"})")
        locked = rc == 0
        unlockedReads = 0
        return locked
    }

    // ------------------------------------------------------------------ mesures
    override fun measure(mode: String, face: Int, sim: JSONObject?): JSONObject {
        busy = true
        try {
            val target = if (mode == "sans_prisme") BAP_REFL_LESS else BAP_REFL_USE
            val current = if (reflectorless) BAP_REFL_LESS else BAP_REFL_USE
            if (target != current) {
                val (rc, _) = request(BAP_SetTargetType, listOf(target))
                check(rc, "type de cible")
                reflectorless = target == BAP_REFL_LESS
            }
            val (rc, vals) = request(BAP_MeasDistanceAngle, listOf(BAP_DEF_DIST), 30000)
            checkTmc(rc, "mesure", needDistance = true)
            if (vals.size < 3) throw GeoComError("mesure incomplète : $vals")
            val hz = rad2gr(vals[0].toDouble())
            val v = rad2gr(vals[1].toDouble())
            val sd = vals[2].toDouble()
            if (sd <= 0.0) throw GeoComError("distance non mesurée (prisme visé ?)")
            lastHz = hz; lastV = v; lastSd = sd
            val obs = JSONObject().put("hz", hz).put("v", v).put("sd", sd)
            if (lastWarning.isNotEmpty()) obs.put("warn", lastWarning)
            return obs
        } finally {
            busy = false
        }
    }

    override fun angles(sim: JSONObject?): JSONObject {
        val (rc, vals) = request(TMC_GetAngle5, listOf(TMC_AUTO_INC))
        checkTmc(rc, "lecture des angles", needDistance = false)
        if (vals.size < 2) throw GeoComError("angles incomplets : $vals")
        val hz = rad2gr(vals[0].toDouble())
        val v = rad2gr(vals[1].toDouble())
        lastHz = hz; lastV = v
        val obs = JSONObject().put("hz", hz).put("v", v)
        if (lastWarning.isNotEmpty()) obs.put("warn", lastWarning)
        return obs
    }

    override fun poll() {
        if (!connected || busy) return
        try {
            val (rc, vals) = request(MOT_ReadLockStatus, emptyList(), 2000)
            if (rc == 0 && vals.isNotEmpty()) {
                // 0 = MOT_LOCKED_OUT, 1 = MOT_LOCKED_IN, 2 = MOT_PREDICTION (suivi conservé)
                val st = vals[0].toIntOrNull() ?: 0
                if (st == 1 || st == 2) { locked = true; unlockedReads = 0 }
                else if (++unlockedReads >= 3) locked = false
            }
            if (tracking) angles(null)
        } catch (e: Exception) {
            lastError = e.message ?: ""
        }
        if (System.currentTimeMillis() - batteryTime > 30000) {
            batteryTime = System.currentTimeMillis()
            try {
                val (rc, vals) = request(CSV_CheckPower, emptyList(), 2000)
                if (rc == 0 && vals.isNotEmpty()) battery = vals[0].toIntOrNull()
            } catch (ignored: Exception) {
            }
        }
    }

    // ------------------------------------------------------------------ pilotage
    override fun search(kind: String, params: JSONObject): JSONObject {
        busy = true
        try {
            val rc: Int
            if (kind.startsWith("powersearch")) {
                request(AUT_PS_EnableRange, listOf(if (kind == "powersearch") 1 else 0))
                if (kind == "powersearch") request(AUT_PS_SetRange, listOf(params.optDouble("min", 1.0), params.optDouble("max", 300.0)))
                rc = request(AUT_PS_SearchNext, listOf(1, 1), 60000).first
            } else {
                val hz = gr2rad(params.optDouble("hz", 10.0))
                val v = gr2rad(params.optDouble("v", 10.0))
                rc = request(AUT_Search, listOf(hz, v, 0), 60000).first
            }
            val found = rc == 0
            if (found) lockIn()
            else AppLog.d("GeoCOM : recherche $kind sans succès, code $rc (${ERRORS[rc] ?: "?"})")
            events.push("tps_search_done", JSONObject().put("found", found).put("type", kind).put("rc", rc).put("locked", locked))
            return ok("found" to found, "rc" to rc, "locked" to locked)
        } finally {
            busy = false
        }
    }

    override fun stop(): JSONObject {
        try { request(MOT_StopController, listOf(0), 2000) } catch (ignored: Exception) {}
        joystickRunning = false
        return ok()
    }

    override fun joystick(direction: String, speed: String): JSONObject {
        val w = if (speed == "rapide") 0.6 else 0.05 // rad/s
        val hz = when (direction) { "gauche" -> -w; "droite" -> w; else -> 0.0 }
        val v = when (direction) { "haut" -> -w; "bas" -> w; else -> 0.0 }
        if (!joystickRunning) {
            request(MOT_StartController, listOf(1)) // MOT_OCONST : vitesse constante
            joystickRunning = true
        }
        val (rc, _) = request(MOT_SetVelocity, listOf(hz, v))
        return JSONObject().put("ok", rc == 0)
    }

    override fun turn(hz: Double, v: Double, search: Boolean): JSONObject {
        busy = true
        try {
            val (rc, _) = request(AUT_MakePositioning, listOf(gr2rad(hz), gr2rad(v), 0, if (search) 1 else 0, 0), 60000)
            check(rc, "positionnement")
            if (search) lockIn()
            return ok("locked" to locked)
        } finally {
            busy = false
        }
    }

    override fun setLock(on: Boolean): JSONObject {
        val (rc, _) = request(AUS_SetUserLockState, listOf(if (on) 1 else 0))
        if (on) lockIn() else { locked = false; unlockedReads = 0 }
        return JSONObject().put("ok", rc == 0).put("locked", locked)
    }

    override fun setLaser(on: Boolean): JSONObject {
        val (rc, _) = request(EDM_Laserpointer, listOf(if (on) 1 else 0))
        laser = on
        return JSONObject().put("ok", rc == 0).put("laser", laser)
    }

    fun setOrientation(hzGr: Double): JSONObject {
        val (rc, _) = request(TMC_SetOrientation, listOf(gr2rad(hzGr)))
        return JSONObject().put("ok", rc == 0)
    }
}
