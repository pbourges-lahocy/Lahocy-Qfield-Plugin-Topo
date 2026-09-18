package fr.lahocy.topolink

import fi.iki.elonen.NanoHTTPD
import org.json.JSONObject

/** Serveur HTTP local (127.0.0.1 uniquement) interrogé par le plugin QField. */
class HttpServer(private val bridge: Bridge, port: Int) : NanoHTTPD("127.0.0.1", port) {

    override fun serve(session: IHTTPSession): Response {
        val method = session.method
        val path = session.uri
        if (method == Method.OPTIONS) return json(200, ok())
        var body = JSONObject()
        if (method == Method.POST) {
            val files = HashMap<String, String>()
            try {
                session.parseBody(files)
            } catch (e: Exception) {
                return json(200, err("corps de requête illisible : ${e.message}"))
            }
            val raw = files["postData"]
            if (!raw.isNullOrBlank()) body = try { JSONObject(raw) } catch (e: Exception) { JSONObject() }
        }
        val query: Map<String, String> = session.parms ?: emptyMap()
        return try {
            json(200, bridge.handle(method.name, path, query, body))
        } catch (e: RouteNotFound) {
            json(404, err("route inconnue $path"))
        } catch (e: Exception) {
            AppLog.e("$path : ${e.message}")
            json(200, err(e.message ?: e.toString()))
        }
    }

    private fun json(code: Int, obj: JSONObject): Response {
        val r = newFixedLengthResponse(Response.Status.lookup(code), "application/json; charset=utf-8", obj.toString())
        r.addHeader("Access-Control-Allow-Origin", "*")
        r.addHeader("Access-Control-Allow-Headers", "Content-Type")
        r.addHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        return r
    }
}
