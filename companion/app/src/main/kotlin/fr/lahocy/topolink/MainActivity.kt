package fr.lahocy.topolink

import android.Manifest
import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.widget.AdapterView
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.util.Locale
import kotlin.concurrent.thread

/**
 * Écran unique : choix de la station appairée, test de la liaison GeoCOM,
 * démarrage / arrêt du pont, journal.
 */
@SuppressLint("SetTextI18n")
class MainActivity : AppCompatActivity() {

    private lateinit var status: TextView
    private lateinit var spinner: Spinner
    private lateinit var logView: TextView
    private lateinit var scroll: ScrollView
    private lateinit var startBtn: Button
    private lateinit var stopBtn: Button
    private var devices: List<BluetoothDevice> = emptyList()
    private val ui = Handler(Looper.getMainLooper())
    private val ticker = object : Runnable {
        override fun run() { refreshStatus(); ui.postDelayed(this, 1000) }
    }

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(16), dp(16), dp(16), dp(16))
        }
        root.addView(TextView(this).apply { text = "Lahocy Topo Link"; textSize = 22f; setTypeface(null, Typeface.BOLD) })
        status = TextView(this).apply { textSize = 15f; setPadding(0, dp(6), 0, dp(10)) }
        root.addView(status)
        root.addView(TextView(this).apply {
            text = "1. Appairer la station dans les réglages Bluetooth d'Android (mode GeoCOM / Bluetooth actif sur la station).\n" +
                "2. Choisir la station ci-dessous puis « Tester la liaison ».\n" +
                "3. « Démarrer le pont », revenir dans QField : Menu station → Paramètres → geocom → Connecter."
            textSize = 13f
        })
        root.addView(TextView(this).apply { text = "Station totale (appareils Bluetooth appairés) :"; setPadding(0, dp(12), 0, dp(4)) })
        spinner = Spinner(this)
        root.addView(spinner)

        val row1 = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row1.addView(Button(this).apply { text = "Actualiser"; setOnClickListener { loadDevices() } }, lp())
        row1.addView(Button(this).apply { text = "Tester la liaison"; setOnClickListener { testStation() } }, lp())
        root.addView(row1)

        val row2 = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        startBtn = Button(this).apply { text = "Démarrer le pont"; setOnClickListener { startBridge() } }
        stopBtn = Button(this).apply { text = "Arrêter"; setOnClickListener { stopBridge() } }
        row2.addView(startBtn, lp())
        row2.addView(stopBtn, lp())
        root.addView(row2)

        root.addView(TextView(this).apply { text = "Journal :"; setPadding(0, dp(12), 0, dp(4)) })
        logView = TextView(this).apply { typeface = Typeface.MONOSPACE; textSize = 11f }
        scroll = ScrollView(this).apply { addView(logView) }
        root.addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)

        spinner.onItemSelectedListener = object : AdapterView.OnItemSelectedListener {
            override fun onItemSelected(parent: AdapterView<*>?, view: View?, position: Int, id: Long) {
                devices.getOrNull(position)?.let { Prefs.setStation(this@MainActivity, it.address, BluetoothHelper.nameOf(it)) }
            }
            override fun onNothingSelected(parent: AdapterView<*>?) {}
        }
        AppLog.listener = { ui.post { refreshLog() } }
        refreshLog()
        requestPermissions()
    }

    private fun lp() = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)

    override fun onResume() {
        super.onResume()
        ui.post(ticker)
    }

    override fun onPause() {
        super.onPause()
        ui.removeCallbacks(ticker)
    }

    // ------------------------------------------------------------------ permissions
    private fun neededPermissions(): List<String> {
        val list = mutableListOf<String>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            list += Manifest.permission.BLUETOOTH_CONNECT
            list += Manifest.permission.BLUETOOTH_SCAN
        } else {
            list += Manifest.permission.ACCESS_FINE_LOCATION
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) list += Manifest.permission.POST_NOTIFICATIONS
        return list.filter { ContextCompat.checkSelfPermission(this, it) != PackageManager.PERMISSION_GRANTED }
    }

    private fun requestPermissions() {
        val missing = neededPermissions()
        if (missing.isEmpty()) loadDevices() else ActivityCompat.requestPermissions(this, missing.toTypedArray(), 1)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (neededPermissions().any { it.startsWith("android.permission.BLUETOOTH") || it == Manifest.permission.ACCESS_FINE_LOCATION }) {
            AppLog.e("Permission Bluetooth refusée : impossible de parler à la station")
        }
        loadDevices()
    }

    // ------------------------------------------------------------------ appareils
    private fun loadDevices() {
        devices = BluetoothHelper.paired(this)
        val names = devices.map { BluetoothHelper.nameOf(it) + "  (" + it.address + ")" }
        spinner.adapter = ArrayAdapter(
            this, android.R.layout.simple_spinner_dropdown_item,
            if (names.isEmpty()) listOf("(aucun appareil appairé)") else names
        )
        val saved = Prefs.stationAddress(this)
        val idx = devices.indexOfFirst { it.address.equals(saved, ignoreCase = true) }
        if (idx >= 0) spinner.setSelection(idx)
        if (BluetoothHelper.adapter(this)?.isEnabled != true) AppLog.e("Bluetooth désactivé")
    }

    private fun selectedTarget(): String = devices.getOrNull(spinner.selectedItemPosition)?.address ?: ""

    // ------------------------------------------------------------------ actions
    private fun startBridge() {
        ContextCompat.startForegroundService(this, Intent(this, BridgeService::class.java))
    }

    private fun stopBridge() {
        stopService(Intent(this, BridgeService::class.java))
    }

    /** Test de liaison GeoCOM : mêmes étapes que bridge/geocom_test.py. */
    private fun testStation() {
        val target = selectedTarget()
        if (target.isEmpty()) { AppLog.e("Choisir d'abord une station appairée"); return }
        val svc = BridgeService.instance
        thread(name = "geocom-test") {
            if (svc != null) {
                // Le pont tourne : on passe par lui, la station reste connectée pour QField.
                AppLog.d("Test via le pont…")
                val r = svc.bridge.tpsConnect(JSONObject().put("driver", "geocom").put("port", target))
                if (!r.optBoolean("ok")) { AppLog.e("ÉCHEC : " + r.optString("error")); return@thread }
                try {
                    val a = svc.bridge.tpsAngles(JSONObject())
                    svc.bridge.tps?.let { report(it, a) }
                    AppLog.d("Liaison OK : station connectée, prête pour QField")
                } catch (e: Exception) {
                    AppLog.e("ÉCHEC : ${e.message}")
                }
            } else {
                val d = GeoComDriver(applicationContext, target, EventBus())
                try {
                    d.connect()
                    val a = d.angles(null)
                    report(d, a)
                    AppLog.d("Liaison OK")
                } catch (e: Exception) {
                    AppLog.e("ÉCHEC : ${e.message}")
                } finally {
                    d.disconnect()
                }
            }
        }
    }

    private fun report(d: TpsDriver, a: JSONObject) {
        AppLog.d("Instrument : ${d.model}  (latence ${d.latencyMs ?: "?"} ms)")
        AppLog.d(String.format(Locale.FRANCE, "Hz = %.4f gon   V = %.4f gon", a.optDouble("hz"), a.optDouble("v")))
        if (a.has("warn")) AppLog.d("Avertissement : " + a.optString("warn"))
        AppLog.d("Batterie : ${d.battery?.toString() ?: "?"} %   Verrouillé : ${if (d.locked) "oui" else "non"}")
    }

    // ------------------------------------------------------------------ affichage
    private fun refreshStatus() {
        val svc = BridgeService.instance
        val text = if (svc == null || !svc.listening) {
            "● Pont arrêté"
        } else {
            val t = svc.bridge.tps
            val st = when {
                t == null -> "aucune station connectée"
                t.connected -> "${t.model} connectée" + (if (t.locked) ", prisme verrouillé" else "")
                else -> "station déconnectée"
            }
            "● Pont en écoute sur 127.0.0.1:${svc.port} : $st"
        }
        if (status.text.toString() != text) status.text = text
        startBtn.isEnabled = svc == null
        stopBtn.isEnabled = svc != null
    }

    private fun refreshLog() {
        logView.text = AppLog.text()
        scroll.post { scroll.fullScroll(View.FOCUS_DOWN) }
    }
}
