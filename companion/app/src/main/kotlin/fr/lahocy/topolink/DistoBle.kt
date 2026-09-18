package fr.lahocy.topolink

import android.annotation.SuppressLint
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.content.Context
import org.json.JSONObject
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Leica DISTO Bluetooth Smart (D110 / D2 / D510 / D810…) en BLE.
 * Service 3ab10100-… ; distance 3ab10101-… (float32 LE, notification) ; commande 3ab10109-… ("g" = mesurer).
 * Une mesure déclenchée sur l'appareil vaut aussi « touche » (télécommande).
 */
@SuppressLint("MissingPermission")
@Suppress("DEPRECATION")
class DistoBle(private val ctx: Context, private val address: String, events: EventBus) : DistoDriver(events) {
    override val name = "disto_ble"

    companion object {
        val SERVICE: UUID = UUID.fromString("3ab10100-f831-4395-b29d-570977d5bf94")
        val CHAR_DISTANCE: UUID = UUID.fromString("3ab10101-f831-4395-b29d-570977d5bf94")
        val CHAR_COMMAND: UUID = UUID.fromString("3ab10109-f831-4395-b29d-570977d5bf94")
        val CCCD: UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
    }

    private var gatt: BluetoothGatt? = null
    @Volatile private var cmdChar: BluetoothGattCharacteristic? = null
    @Volatile private var ready = CountDownLatch(1)
    @Volatile private var measureLatch: CountDownLatch? = null

    init { model = "Leica DISTO" }

    override fun connect() {
        val adapter = BluetoothHelper.adapter(ctx) ?: throw RuntimeException("Bluetooth indisponible")
        var dev: BluetoothDevice? = if (address.isNotBlank()) adapter.getRemoteDevice(address.uppercase()) else null
        if (dev == null) dev = BluetoothHelper.paired(ctx).firstOrNull { BluetoothHelper.nameOf(it).uppercase().contains("DISTO") }
        if (dev == null) dev = scanForDisto(adapter.bluetoothLeScanner)
        if (dev == null) throw RuntimeException("aucun DISTO trouvé (allumer le Bluetooth du DISTO)")
        model = BluetoothHelper.nameOf(dev)
        AppLog.d("DISTO : connexion à $model")
        ready = CountDownLatch(1)
        cmdChar = null
        gatt = dev.connectGatt(ctx, false, callback, BluetoothDevice.TRANSPORT_LE)
        if (!ready.await(30, TimeUnit.SECONDS)) { disconnect(); throw RuntimeException("connexion DISTO impossible (délai)") }
        if (cmdChar == null) { disconnect(); throw RuntimeException("service DISTO introuvable sur $model") }
        connected = true
        lastError = ""
        AppLog.d("DISTO : prêt")
    }

    private fun scanForDisto(scanner: BluetoothLeScanner?): BluetoothDevice? {
        if (scanner == null) return null
        var found: BluetoothDevice? = null
        val latch = CountDownLatch(1)
        val cb = object : ScanCallback() {
            override fun onScanResult(callbackType: Int, result: ScanResult) {
                val n = result.device.name ?: result.scanRecord?.deviceName ?: return
                if (n.uppercase().contains("DISTO")) { found = result.device; latch.countDown() }
            }
        }
        try {
            scanner.startScan(cb)
            latch.await(6, TimeUnit.SECONDS)
        } finally {
            try { scanner.stopScan(cb) } catch (ignored: Exception) {}
        }
        return found
    }

    private val callback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                g.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                if (connected) {
                    connected = false
                    lastError = "DISTO déconnecté"
                    events.push("disto_disconnected")
                }
                ready.countDown()
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt, status: Int) {
            val svc = g.getService(SERVICE)
            if (svc != null) {
                val dist = svc.getCharacteristic(CHAR_DISTANCE)
                cmdChar = svc.getCharacteristic(CHAR_COMMAND)
                if (dist != null) {
                    g.setCharacteristicNotification(dist, true)
                    val cccd = dist.getDescriptor(CCCD)
                    if (cccd != null) {
                        cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        g.writeDescriptor(cccd)
                    }
                }
            }
            ready.countDown()
        }

        override fun onCharacteristicChanged(g: BluetoothGatt, c: BluetoothGattCharacteristic) {
            if (c.uuid != CHAR_DISTANCE) return
            val v = c.value ?: return
            if (v.size < 4) return
            val d = ByteBuffer.wrap(v, 0, 4).order(ByteOrder.LITTLE_ENDIAN).float.toDouble()
            onDistance(d)
        }
    }

    private fun onDistance(d: Double) {
        lastDistance = Math.round(d * 10000.0) / 10000.0
        lastKey = "measure"
        events.push("disto_measure", JSONObject().put("distance", lastDistance))
        events.push("disto_key", JSONObject().put("key", "measure"))
        measureLatch?.countDown()
    }

    override fun measure(sim: JSONObject?): Double {
        val g = gatt ?: throw RuntimeException("DISTO non connecté")
        val c = cmdChar ?: throw RuntimeException("DISTO non connecté")
        val latch = CountDownLatch(1)
        measureLatch = latch
        c.value = "g".toByteArray(Charsets.US_ASCII)
        if (!g.writeCharacteristic(c)) throw RuntimeException("commande DISTO refusée")
        if (!latch.await(10, TimeUnit.SECONDS)) throw RuntimeException("pas de mesure DISTO reçue")
        return lastDistance ?: throw RuntimeException("pas de mesure DISTO reçue")
    }

    override fun disconnect() {
        connected = false
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (ignored: Exception) {
        }
        gatt = null
        cmdChar = null
    }
}
