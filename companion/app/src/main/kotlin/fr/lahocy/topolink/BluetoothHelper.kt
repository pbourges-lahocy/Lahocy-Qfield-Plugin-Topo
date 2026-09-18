package fr.lahocy.topolink

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.content.Context
import java.util.UUID

@SuppressLint("MissingPermission")
object BluetoothHelper {
    /** Profil série (SPP) : station totale en mode GeoCOM, détecteur de réseaux. */
    val SPP_UUID: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

    fun adapter(ctx: Context): BluetoothAdapter? =
        (ctx.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    fun paired(ctx: Context): List<BluetoothDevice> = try {
        adapter(ctx)?.bondedDevices?.toList()?.sortedBy { nameOf(it) } ?: emptyList()
    } catch (e: SecurityException) {
        emptyList()
    }

    fun nameOf(d: BluetoothDevice): String = try { d.name ?: d.address } catch (e: SecurityException) { d.address }

    /**
     * Résout le « port » envoyé par le plugin : vide = station choisie dans l'application,
     * adresse MAC, ou nom Bluetooth (exact puis partiel) parmi les appareils appairés.
     */
    fun findDevice(ctx: Context, target: String): BluetoothDevice? {
        val t = target.trim()
        val list = paired(ctx)
        if (t.isEmpty()) {
            val saved = Prefs.stationAddress(ctx)
            return list.firstOrNull { it.address.equals(saved, ignoreCase = true) }
                ?: list.firstOrNull { looksLikeStation(nameOf(it)) }
        }
        if (BluetoothAdapter.checkBluetoothAddress(t.uppercase())) return adapter(ctx)?.getRemoteDevice(t.uppercase())
        return list.firstOrNull { nameOf(it).equals(t, ignoreCase = true) }
            ?: list.firstOrNull { nameOf(it).contains(t, ignoreCase = true) }
    }

    private fun looksLikeStation(name: String): Boolean {
        val n = name.uppercase()
        return listOf("TS", "TCR", "TCRP", "TPS", "MS", "RH", "LEICA").any { n.startsWith(it) }
    }
}
