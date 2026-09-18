package fr.lahocy.topolink

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import kotlin.concurrent.thread

class RouteNotFound(path: String) : Exception(path)

/**
 * Cœur du pont : mêmes routes et mêmes réponses JSON que bridge/topo_bridge.py.
 * Aucune logique topographique ici : le plugin QField fait tous les calculs.
 */
class Bridge(private val ctx: Context) {
    val events = EventBus()
    @Volatile var tps: TpsDriver? = null
    @Volatile var disto: DistoDriver? = null
    @Volatile var detector: DetectorDriver? = null
    private val lock = Any()
    val tpsState: JSONObject = JSONObject().put("hr", 1.5).put("prism", "standard").put("atr", true)
    @Volatile var detectorPending: JSONObject? = null
    @Volatile private var running = true

    init {
        thread(isDaemon = true, name = "bridge-monitor") { monitorLoop() }
    }

    fun close() {
        running = false
        try { tps?.disconnect() } catch (ignored: Exception) {}
        try { disto?.disconnect() } catch (ignored: Exception) {}
        try { detector?.disconnect() } catch (ignored: Exception) {}
        tps = null; disto = null; detector = null
    }

    // ------------------------------------------------------------------ status
    fun status(): JSONObject {
        val t = tps
        val tpsJ = JSONObject()
            .put("connected", t != null && t.connected).put("driver", t?.name ?: "").put("model", t?.model ?: "")
            .put("locked", t != null && t.locked).putN("latency_ms", t?.latencyMs).putN("battery", t?.battery)
            .putN("hz", t?.lastHz).putN("v", t?.lastV).putN("sd", t?.lastSd)
            .put("tracking", t != null && t.tracking).put("hr", tpsState.opt("hr"))
            .put("busy", t != null && t.busy).put("error", t?.lastError ?: "")
        val d = disto
        val distoJ = JSONObject()
            .put("connected", d != null && d.connected).put("driver", d?.name ?: "")
            .putN("last_distance", d?.lastDistance).putN("last_key", d?.lastKey).put("error", d?.lastError ?: "")
        val det = detector
        val detJ = JSONObject()
            .put("connected", det != null && det.connected).put("driver", det?.name ?: "")
            .putN("pending", detectorPending).put("error", det?.lastError ?: "")
        return JSONObject().put("ok", true).put("time", now()).put("seq", events.seq)
            .put("tps", tpsJ).put("disto", distoJ).put("detector", detJ)
    }

    fun drivers(): JSONObject {
        val ports = JSONArray()
        for (dev in BluetoothHelper.paired(ctx)) {
            ports.put(JSONObject().put("port", dev.address).put("description", BluetoothHelper.nameOf(dev)))
        }
        val drivers = JSONObject()
            .put("tps", JSONArray(listOf("simulateur", "geocom")))
            .put("disto", JSONArray(listOf("simulateur", "disto_ble")))
            .put("detector", JSONArray(listOf("simulateur", "detector")))
        return JSONObject().put("ok", true).put("drivers", drivers).put("ports", ports)
    }

    // ------------------------------------------------------------------ TPS
    fun tpsConnect(body: JSONObject): JSONObject {
        val driver = body.str("driver", "simulateur")
        val port = body.str("port", "")
        val t: TpsDriver
        synchronized(lock) {
            try { tps?.disconnect() } catch (ignored: Exception) {}
            t = if (driver == "geocom") GeoComDriver(ctx, port, events) else SimTps(events)
            tps = t
            try {
                t.connect()
                t.setup(tpsState)
            } catch (e: Exception) {
                t.lastError = e.message ?: e.toString()
                AppLog.e("Station : ${t.lastError}")
                return err(t.lastError)
            }
        }
        events.push("tps_connected", JSONObject().put("driver", driver).put("model", t.model))
        AppLog.d("Station connectée : ${t.model}")
        return ok("model" to t.model)
    }

    fun tpsDisconnect(): JSONObject {
        synchronized(lock) {
            tps?.disconnect()
            tps = null
        }
        events.push("tps_disconnected")
        return ok()
    }

    fun needTps(): TpsDriver {
        val t = tps
        if (t == null || !t.connected) throw RuntimeException("Station non connectée")
        return t
    }

    fun tpsMeasure(body: JSONObject): JSONObject {
        val t = needTps()
        val mode = body.str("mode", "prisme")
        val face = body.optInt("face", 1)
        val obs = t.measure(mode, face, body.objOrNull("sim"))
        obs.put("ok", true).put("hr", tpsState.opt("hr")).put("face", face).put("mode", mode).put("t", now())
        events.push("tps_measure", obs)
        return obs
    }

    fun tpsAngles(body: JSONObject): JSONObject {
        val obs = needTps().angles(body.objOrNull("sim"))
        return obs.put("ok", true).put("t", now())
    }

    // ------------------------------------------------------------------ monitor (suivi prisme)
    private fun monitorLoop() {
        var wasLocked: Boolean? = null
        while (running) {
            try { Thread.sleep(500) } catch (e: InterruptedException) { return }
            val t = tps
            if (t != null && t.connected) {
                try { t.poll() } catch (e: Exception) { t.lastError = e.message ?: "" }
                if (t.locked != wasLocked) {
                    events.push("tps_lock", JSONObject().put("locked", t.locked))
                    wasLocked = t.locked
                }
            }
            val d = disto
            if (d != null && d.connected) {
                try { d.poll() } catch (e: Exception) { d.lastError = e.message ?: "" }
            }
            val det = detector
            if (det != null && det.connected) {
                try {
                    val m = det.pollMeasure()
                    if (m != null) {
                        detectorPending = m
                        events.push("detector_measure", m)
                    }
                } catch (e: Exception) {
                    det.lastError = e.message ?: ""
                }
            }
        }
    }

    // ------------------------------------------------------------------ disto
    fun distoConnect(body: JSONObject): JSONObject {
        val driver = body.str("driver", "simulateur")
        synchronized(lock) {
            try { disto?.disconnect() } catch (ignored: Exception) {}
            val d: DistoDriver = if (driver == "disto_ble") DistoBle(ctx, body.str("address", ""), events) else SimDisto(events)
            disto = d
            try {
                d.connect()
            } catch (e: Exception) {
                d.lastError = e.message ?: e.toString()
                AppLog.e("Disto : ${d.lastError}")
                return err(d.lastError)
            }
        }
        events.push("disto_connected", JSONObject().put("driver", driver))
        return ok()
    }

    fun distoMeasure(body: JSONObject): JSONObject {
        val d = disto
        if (d == null || !d.connected) throw RuntimeException("Disto non connecté")
        val dist = d.measure(body.objOrNull("sim"))
        events.push("disto_measure", JSONObject().put("distance", dist))
        return ok("distance" to dist)
    }

    // ------------------------------------------------------------------ détecteur
    fun detectorConnect(body: JSONObject): JSONObject {
        val driver = body.str("driver", "simulateur")
        synchronized(lock) {
            try { detector?.disconnect() } catch (ignored: Exception) {}
            val d: DetectorDriver = if (driver == "detector")
                SerialDetector(ctx, body.str("port", ""), body.str("model", "generic"), events)
            else SimDetector(events)
            detector = d
            try {
                d.connect()
            } catch (e: Exception) {
                d.lastError = e.message ?: e.toString()
                AppLog.e("Détecteur : ${d.lastError}")
                return err(d.lastError)
            }
        }
        events.push("detector_connected", JSONObject().put("driver", driver))
        return ok()
    }

    fun detectorSimulate(body: JSONObject): JSONObject {
        val m = JSONObject().put("profondeur", body.optDouble("profondeur", 0.0)).put("index", body.str("index", ""))
            .putN("intensite", body.opt("intensite")).putN("frequence", body.opt("frequence"))
            .put("mode", body.str("mode", "manuel")).put("t", now())
        detectorPending = m
        events.push("detector_measure", m)
        return ok("pending" to m)
    }

    // ------------------------------------------------------------------ dispatch
    fun handle(method: String, path: String, query: Map<String, String>, body: JSONObject): JSONObject {
        if (method == "GET") {
            return when (path) {
                "/status" -> status()
                "/drivers" -> drivers()
                "/events" -> {
                    val since = query["since"]?.toLongOrNull() ?: 0L
                    val timeout = query["timeout"]?.toDoubleOrNull() ?: 25.0
                    JSONObject().put("ok", true).put("seq", events.seq)
                        .put("events", JSONArray(events.since(since, (timeout * 1000).toLong())))
                }
                "/detector/pending" -> ok("pending" to detectorPending)
                else -> throw RouteNotFound(path)
            }
        }
        val t = tps
        return when (path) {
            "/tps/connect" -> tpsConnect(body)
            "/tps/disconnect" -> tpsDisconnect()
            "/tps/measure" -> tpsMeasure(body)
            "/tps/angles" -> tpsAngles(body)
            "/tps/search" -> needTps().search(body.str("type", "powersearch"), body)
            "/tps/stop" -> needTps().stop()
            "/tps/joystick" -> needTps().joystick(body.str("dir", ""), body.str("speed", "lent"))
            "/tps/turn" -> needTps().turn(body.optDouble("hz", 0.0), body.optDouble("v", 100.0), body.optBoolean("search", false))
            "/tps/lock" -> needTps().setLock(body.optBoolean("on", true))
            "/tps/laser" -> needTps().setLaser(body.optBoolean("on", true))
            "/tps/tracking" -> needTps().setTracking(body.optBoolean("on", true))
            "/tps/setup" -> {
                for (k in listOf("hr", "prism", "atr")) if (body.has(k)) tpsState.put(k, body.get(k))
                if (t != null && t.connected) t.setup(tpsState)
                ok("state" to tpsState)
            }
            "/disto/connect" -> distoConnect(body)
            "/disto/measure" -> distoMeasure(body)
            "/disto/simulate" -> {
                events.push("disto_key", JSONObject().put("key", body.str("key", "")))
                if (body.has("distance")) events.push("disto_measure", JSONObject().put("distance", body.optDouble("distance", 0.0)))
                ok()
            }
            "/detector/connect" -> detectorConnect(body)
            "/detector/simulate" -> detectorSimulate(body)
            "/detector/ack" -> { detectorPending = null; ok() }
            else -> throw RouteNotFound(path)
        }
    }
}
