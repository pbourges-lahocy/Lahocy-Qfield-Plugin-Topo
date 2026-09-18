package fr.lahocy.topolink

import android.annotation.SuppressLint
import android.bluetooth.BluetoothSocket
import android.content.Context
import org.json.JSONObject
import java.io.IOException
import java.io.InputStream
import java.util.concurrent.LinkedBlockingQueue
import kotlin.concurrent.thread

/**
 * Détecteur de réseaux sur liaison série Bluetooth SPP (RD8100 / RD8200, vLoc3…).
 * Lecture de lignes texte : "DEPTH=1.23;CURRENT=12.5;FREQ=8192" ou "1.23".
 * Portage de bridge/drivers/detector.py (trames exactes à adapter sur le terrain).
 */
@SuppressLint("MissingPermission")
class SerialDetector(private val ctx: Context, private val target: String, modelName: String, events: EventBus) : DetectorDriver(events) {
    override val name = "detector"
    private var socket: BluetoothSocket? = null
    private val measures = LinkedBlockingQueue<JSONObject>()
    private val kvRegex = Regex("([A-Za-z_]+)\\s*[=:]\\s*([-+]?\\d+(?:\\.\\d+)?)")
    private val numRegex = Regex("[-+]?\\d+\\.\\d+")

    init { model = if (modelName.isBlank()) "generic" else modelName }

    override fun connect() {
        val dev = BluetoothHelper.findDevice(ctx, target)
            ?: throw RuntimeException("détecteur Bluetooth introuvable : $target (appairé ?)")
        BluetoothHelper.adapter(ctx)?.cancelDiscovery()
        val s = dev.createRfcommSocketToServiceRecord(BluetoothHelper.SPP_UUID)
        try {
            s.connect()
        } catch (e: IOException) {
            try { s.close() } catch (ignored: IOException) {}
            throw RuntimeException("connexion Bluetooth refusée par ${BluetoothHelper.nameOf(dev)} : ${e.message}")
        }
        socket = s
        connected = true
        lastError = ""
        AppLog.d("Détecteur : connecté à ${BluetoothHelper.nameOf(dev)}")
        thread(isDaemon = true, name = "detector-reader") { readLoop(s.inputStream) }
    }

    override fun disconnect() {
        connected = false
        try { socket?.close() } catch (ignored: IOException) {}
        socket = null
    }

    private fun readLoop(input: InputStream) {
        val buf = ByteArray(256)
        val sb = StringBuilder()
        try {
            while (connected) {
                val n = input.read(buf)
                if (n < 0) break
                for (i in 0 until n) {
                    val c = (buf[i].toInt() and 0xff).toChar()
                    if (c == '\n') {
                        parse(sb.toString().trim())?.let { measures.offer(it) }
                        sb.setLength(0)
                    } else if (c != '\r') {
                        sb.append(c)
                    }
                }
            }
        } catch (e: IOException) {
            lastError = e.message ?: "liaison perdue"
        }
        if (connected) {
            connected = false
            events.push("detector_disconnected")
        }
    }

    override fun pollMeasure(): JSONObject? = measures.poll()

    fun parse(line: String): JSONObject? {
        if (line.isEmpty()) return null
        var profondeur: Double? = null
        var intensite: Double? = null
        var frequence: Double? = null
        var index = ""
        for (m in kvRegex.findAll(line)) {
            val k = m.groupValues[1].lowercase()
            val v = m.groupValues[2]
            when {
                k.startsWith("depth") || k.startsWith("prof") -> profondeur = v.toDoubleOrNull()
                k.startsWith("curr") || k.startsWith("int") || k.startsWith("sig") -> intensite = v.toDoubleOrNull()
                k.startsWith("freq") -> frequence = v.toDoubleOrNull()
                k.startsWith("idx") || k.startsWith("index") || k.startsWith("id") -> index = v
            }
        }
        if (profondeur == null) profondeur = numRegex.find(line)?.value?.toDoubleOrNull()
        var p = profondeur ?: return null
        // unités en mm ou cm ?
        if (p > 50) p = if (p < 1000) p / 100.0 else p / 1000.0
        return JSONObject().put("raw", line).put("mode", "auto").put("t", now()).put("index", index)
            .putN("intensite", intensite).putN("frequence", frequence).put("profondeur", p)
    }
}
