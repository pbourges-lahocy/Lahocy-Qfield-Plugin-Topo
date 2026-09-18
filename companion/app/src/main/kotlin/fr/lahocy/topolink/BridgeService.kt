package fr.lahocy.topolink

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import fi.iki.elonen.NanoHTTPD

/** Service de premier plan : garde la liaison Bluetooth et le serveur HTTP vivants pendant que QField est devant. */
class BridgeService : Service() {

    companion object {
        @Volatile var instance: BridgeService? = null
        const val CHANNEL = "topolink"
        const val ACTION_STOP = "fr.lahocy.topolink.STOP"
        const val NOTIF_ID = 1
    }

    lateinit var bridge: Bridge
        private set
    private var server: HttpServer? = null
    val port: Int get() = Prefs.port(this)
    val listening: Boolean get() = server?.isAlive == true

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        bridge = Bridge(applicationContext)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            startForegroundCompat()
        } catch (e: Exception) {
            AppLog.e("Service de premier plan refusé : ${e.message} (permission Bluetooth accordée ?)")
            stopSelf()
            return START_NOT_STICKY
        }
        if (server == null) {
            try {
                server = HttpServer(bridge, port).also { it.start(NanoHTTPD.SOCKET_READ_TIMEOUT, false) }
                AppLog.d("Pont en écoute sur http://127.0.0.1:$port")
            } catch (e: Exception) {
                AppLog.e("Impossible d'ouvrir le port $port : ${e.message}")
                stopSelf()
            }
        }
        return START_STICKY
    }

    private fun startForegroundCompat() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        nm.createNotificationChannel(NotificationChannel(CHANNEL, "Lahocy Topo Link", NotificationManager.IMPORTANCE_LOW))
        val open = PendingIntent.getActivity(
            this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stop = PendingIntent.getService(
            this, 1, Intent(this, BridgeService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val noIcon: Icon? = null
        val n = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_launcher)
            .setContentTitle("Lahocy Topo Link")
            .setContentText("Pont appareils actif sur 127.0.0.1:$port")
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(noIcon, "Arrêter", stop).build())
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(NOTIF_ID, n)
        }
    }

    override fun onDestroy() {
        try { server?.stop() } catch (ignored: Exception) {}
        server = null
        try { bridge.close() } catch (ignored: Exception) {}
        instance = null
        AppLog.d("Pont arrêté")
        super.onDestroy()
    }
}
