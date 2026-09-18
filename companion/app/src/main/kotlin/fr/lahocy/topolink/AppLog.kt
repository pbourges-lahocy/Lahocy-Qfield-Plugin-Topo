package fr.lahocy.topolink

import android.util.Log
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Journal affiché dans l'application (300 dernières lignes). */
object AppLog {
    private const val TAG = "TopoLink"
    private val lines = ArrayDeque<String>()
    private val fmt = SimpleDateFormat("HH:mm:ss", Locale.FRANCE)
    @Volatile var listener: (() -> Unit)? = null

    @Synchronized
    fun d(msg: String) {
        Log.d(TAG, msg)
        add(msg)
    }

    @Synchronized
    fun e(msg: String) {
        Log.e(TAG, msg)
        add("ERREUR : $msg")
    }

    private fun add(msg: String) {
        lines.addLast(fmt.format(Date()) + "  " + msg)
        while (lines.size > 300) lines.removeFirst()
        listener?.invoke()
    }

    @Synchronized
    fun text(): String = lines.joinToString("\n")
}
