package fr.lahocy.topolink

import org.json.JSONObject

/** File d'événements consommée par le plugin en long-poll (GET /events?since=N). */
class EventBus {
    private val lock = Object()
    @Volatile var seq: Long = 0
        private set
    private val events = ArrayDeque<JSONObject>()

    fun push(kind: String, data: JSONObject = JSONObject()) {
        synchronized(lock) {
            seq++
            events.addLast(JSONObject().put("seq", seq).put("kind", kind).put("t", now()).put("data", data))
            while (events.size > 500) events.removeFirst()
            lock.notifyAll()
        }
    }

    fun since(n: Long, timeoutMs: Long): List<JSONObject> {
        val deadline = System.currentTimeMillis() + timeoutMs
        synchronized(lock) {
            while (true) {
                val out = events.filter { it.getLong("seq") > n }
                if (out.isNotEmpty()) return out
                val remaining = deadline - System.currentTimeMillis()
                if (remaining <= 0) return emptyList()
                lock.wait(remaining)
            }
        }
    }
}
