package fr.lahocy.topolink

import org.json.JSONObject

/** Petites aides org.json : les valeurs nulles deviennent JSON null (et non l'absence de clé). */
fun JSONObject.putN(key: String, value: Any?): JSONObject = put(key, value ?: JSONObject.NULL)

fun ok(vararg pairs: Pair<String, Any?>): JSONObject {
    val o = JSONObject().put("ok", true)
    for ((k, v) in pairs) o.putN(k, v)
    return o
}

fun err(message: String): JSONObject = JSONObject().put("ok", false).put("error", message)

fun JSONObject.str(key: String, default: String): String =
    if (has(key) && !isNull(key)) optString(key, default) else default

fun JSONObject.objOrNull(key: String): JSONObject? = if (has(key) && !isNull(key)) optJSONObject(key) else null

fun now(): Double = System.currentTimeMillis() / 1000.0
