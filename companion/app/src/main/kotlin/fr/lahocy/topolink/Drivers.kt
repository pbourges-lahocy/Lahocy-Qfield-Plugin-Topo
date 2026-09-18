package fr.lahocy.topolink

import org.json.JSONObject
import kotlin.math.PI

/** Angles en GRADES, distances en mètres (même contrat que bridge/drivers/base.py). */
fun rad2gr(r: Double): Double = r * 200.0 / PI
fun gr2rad(g: Double): Double = g * PI / 200.0

abstract class Driver(val events: EventBus) {
    abstract val name: String
    @Volatile var connected = false
    @Volatile var model = ""
    @Volatile var lastError = ""

    open fun connect() { connected = true }
    open fun disconnect() { connected = false }
    /** Appelé toutes les 0,5 s par le pont (suivi, événements). */
    open fun poll() {}
}

abstract class TpsDriver(events: EventBus) : Driver(events) {
    @Volatile var locked = false
    @Volatile var tracking = false
    @Volatile var busy = false
    @Volatile var latencyMs: Int? = null
    @Volatile var battery: Int? = null
    @Volatile var lastHz: Double? = null
    @Volatile var lastV: Double? = null
    @Volatile var lastSd: Double? = null

    open fun setup(state: JSONObject) {}
    /** Renvoie {hz, v, sd} (grades, mètres). */
    abstract fun measure(mode: String, face: Int, sim: JSONObject?): JSONObject
    abstract fun angles(sim: JSONObject?): JSONObject
    open fun search(kind: String, params: JSONObject): JSONObject = err("recherche non supportée")
    open fun stop(): JSONObject = ok()
    open fun joystick(direction: String, speed: String): JSONObject = err("joystick non supporté")
    open fun turn(hz: Double, v: Double, search: Boolean): JSONObject = err("positionnement non supporté")
    open fun setLock(on: Boolean): JSONObject = err("verrouillage non supporté")
    open fun setLaser(on: Boolean): JSONObject = err("laser non supporté")
    open fun setTracking(on: Boolean): JSONObject { tracking = on; return ok() }
}

abstract class DistoDriver(events: EventBus) : Driver(events) {
    @Volatile var lastDistance: Double? = null
    @Volatile var lastKey: String? = null
    abstract fun measure(sim: JSONObject?): Double
}

abstract class DetectorDriver(events: EventBus) : Driver(events) {
    /** Renvoie une mesure {profondeur, index, intensite, frequence, mode, t} ou null. */
    open fun pollMeasure(): JSONObject? = null
}

// ---------------------------------------------------------------- simulateurs (« entrée clavier »)

class SimTps(events: EventBus) : TpsDriver(events) {
    override val name = "simulateur"
    private var hz = 0.0
    private var v = 100.0
    private var laser = false

    init { model = "Simulateur (entrée clavier)" }

    override fun connect() {
        connected = true; locked = true; latencyMs = 5; battery = 100
    }

    override fun measure(mode: String, face: Int, sim: JSONObject?): JSONObject {
        busy = true
        try {
            val sd: Double
            if (sim != null && sim.has("hz")) {
                hz = sim.optDouble("hz", hz); v = sim.optDouble("v", v); sd = sim.optDouble("sd", 0.0)
            } else {
                hz = ((hz + (Math.random() * 30 - 15)) % 400 + 400) % 400
                v = 100.0 + (Math.random() * 6 - 3)
                sd = 5 + Math.random() * 55
            }
            val (h, vv) = if (face == 2) Pair((hz + 200) % 400, 400 - v) else Pair(hz, v)
            lastHz = h; lastV = vv; lastSd = sd
            Thread.sleep(200)
            return JSONObject().put("hz", h).put("v", vv).put("sd", sd)
        } finally {
            busy = false
        }
    }

    override fun angles(sim: JSONObject?): JSONObject {
        if (sim != null && sim.has("hz")) { hz = sim.optDouble("hz", hz); v = sim.optDouble("v", v) }
        lastHz = hz; lastV = v
        return JSONObject().put("hz", hz).put("v", v)
    }

    override fun search(kind: String, params: JSONObject): JSONObject {
        Thread.sleep(500)
        locked = true
        events.push("tps_search_done", JSONObject().put("found", true).put("type", kind))
        return ok("found" to true)
    }

    override fun joystick(direction: String, speed: String): JSONObject {
        val step = if (speed == "rapide") 5.0 else 0.5
        when (direction) {
            "gauche" -> hz = ((hz - step) % 400 + 400) % 400
            "droite" -> hz = (hz + step) % 400
            "haut" -> v = maxOf(0.0, v - step)
            "bas" -> v = minOf(200.0, v + step)
        }
        lastHz = hz; lastV = v
        return ok("hz" to hz, "v" to v)
    }

    override fun turn(hz: Double, v: Double, search: Boolean): JSONObject {
        this.hz = (hz % 400 + 400) % 400; this.v = v
        lastHz = this.hz; lastV = this.v
        if (search) locked = true
        return ok("hz" to this.hz, "v" to this.v, "locked" to locked)
    }

    override fun setLock(on: Boolean): JSONObject { locked = on; return ok("locked" to locked) }
    override fun setLaser(on: Boolean): JSONObject { laser = on; return ok("laser" to laser) }
}

class SimDisto(events: EventBus) : DistoDriver(events) {
    override val name = "simulateur"
    init { model = "Disto simulé" }
    override fun measure(sim: JSONObject?): Double {
        val d = if (sim != null && sim.has("distance")) sim.optDouble("distance", 1.0)
        else Math.round((0.3 + Math.random() * 7.7) * 1000.0) / 1000.0
        lastDistance = d
        return d
    }
}

class SimDetector(events: EventBus) : DetectorDriver(events) {
    override val name = "simulateur"
    init { model = "Détecteur simulé (saisie manuelle)" }
}
