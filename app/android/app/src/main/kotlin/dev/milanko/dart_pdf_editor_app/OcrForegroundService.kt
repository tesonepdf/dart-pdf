package dev.milanko.dart_pdf_editor_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/// Tiene vivo il processo dell'app mentre l'OCR lavora in background.
///
/// Parte quando l'OCR inizia e si ferma quando finisce (o viene annullato):
/// finché è attivo, Android non ferma l'app anche se l'utente apre un'altra
/// applicazione, e la notifica mostra la pagina in corso. Il lavoro vero lo
/// fa il codice Dart; questo servizio non legge nessun documento.
class OcrForegroundService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = true
        try {
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:ocr").apply {
                setReferenceCounted(false)
                // Scade da solo: un servizio dimenticato non tiene sveglio il telefono.
                acquire(WAKE_LOCK_TIMEOUT_MS)
            }
        } catch (e: Exception) {
            wakeLock = null
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: ""
        val page = intent?.getIntExtra(EXTRA_PAGE, 0) ?: 0
        val pageCount = intent?.getIntExtra(EXTRA_PAGE_COUNT, 0) ?: 0
        val notification = buildNotification(this, title, page, pageCount)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        running = false
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (e: Exception) {
            // già rilasciato
        }
        wakeLock = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL_ID = "ocr_progress"
        private const val NOTIFICATION_ID = 0x0C01
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_PAGE = "page"
        private const val EXTRA_PAGE_COUNT = "pageCount"
        private const val WAKE_LOCK_TIMEOUT_MS = 3L * 60L * 60L * 1000L

        /// Vero mentre il servizio è attivo: evita che un aggiornamento in
        /// ritardo rimetta la notifica dopo lo stop.
        @Volatile
        private var running = false

        fun intent(context: Context, title: String, page: Int, pageCount: Int): Intent =
            Intent(context, OcrForegroundService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_PAGE, page)
                .putExtra(EXTRA_PAGE_COUNT, pageCount)

        /// Aggiorna la notifica con la pagina in corso.
        fun notifyProgress(context: Context, title: String, page: Int, pageCount: Int) {
            if (!running) return
            try {
                val manager = context.getSystemService(NotificationManager::class.java)
                manager.notify(NOTIFICATION_ID, buildNotification(context, title, page, pageCount))
            } catch (e: Exception) {
                // La notifica è un di più: l'OCR non si ferma per lei.
            }
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return
            val channel = NotificationChannel(
                CHANNEL_ID,
                "OCR in background",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Avanzamento della lettura OCR dei documenti"
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }

        private fun buildNotification(
            context: Context,
            title: String,
            page: Int,
            pageCount: Int
        ): Notification {
            ensureChannel(context)
            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            val contentIntent = launch?.let {
                PendingIntent.getActivity(
                    context,
                    0,
                    it,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                )
            }
            val progressText = if (pageCount > 0) "Pagina $page di $pageCount" else "Preparazione…"
            val text = if (title.isEmpty()) progressText else "$title: $progressText"
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.stat_notify_sync)
                .setContentTitle("OCR in corso")
                .setContentText(text)
                .setOnlyAlertOnce(true)
                .setOngoing(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setPriority(NotificationCompat.PRIORITY_LOW)
            if (pageCount > 0) {
                builder.setProgress(pageCount, (page - 1).coerceIn(0, pageCount), false)
            } else {
                builder.setProgress(0, 0, true)
            }
            if (contentIntent != null) builder.setContentIntent(contentIntent)
            return builder.build()
        }
    }
}
