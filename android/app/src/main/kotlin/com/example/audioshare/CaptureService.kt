package com.example.audioshare

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

class CaptureService : Service() {
    private var projection: MediaProjection? = null
    private var record: AudioRecord? = null
    private var thread: Thread? = null
    @Volatile private var running = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopCapture()
            stopSelf()
            return START_NOT_STICKY
        }
        val code = intent?.getIntExtra(EXTRA_CODE, 0) ?: 0
        val uid = intent?.getIntExtra(EXTRA_UID, -1) ?: -1
        @Suppress("DEPRECATION")
        val data: Intent? = if (Build.VERSION.SDK_INT >= 33)
            intent?.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        else intent?.getParcelableExtra(EXTRA_DATA)
        if (data == null) {
            CaptureBus.error("No llegó el permiso de captura.")
            stopSelf()
            return START_NOT_STICKY
        }

        // Android exige estar en primer plano ANTES de obtener la proyección.
        startForeground(NOTIFICATION_ID, notification(), ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        try {
            startCapture(code, data, uid)
        } catch (e: Exception) {
            CaptureBus.error("No se pudo iniciar la captura de audio: ${e.message}")
            stopCapture()
            stopSelf()
        }
        return START_NOT_STICKY
    }

    private fun startCapture(code: Int, data: Intent, uid: Int) {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        val mp = manager.getMediaProjection(code, data) ?: throw IllegalStateException("sin proyección")
        // Obligatorio desde Android 14: registrar el callback antes de capturar.
        mp.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() { stopCapture(); stopSelf() }
        }, Handler(Looper.getMainLooper()))
        projection = mp

        val builder = AudioPlaybackCaptureConfiguration.Builder(mp)
        if (uid >= 0) {
            // «Una aplicación»: solo el audio que reproduce esa app.
            builder.addMatchingUid(uid)
        } else {
            // «Todo el dispositivo»: todo el audio que Android permite capturar.
            builder
                .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
                .addMatchingUsage(AudioAttributes.USAGE_GAME)
                .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
        }
        val config = builder.build()
        val format = AudioFormat.Builder()
            .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
            .setSampleRate(SAMPLE_RATE)
            .setChannelMask(AudioFormat.CHANNEL_IN_STEREO)
            .build()
        val minBuffer = AudioRecord.getMinBufferSize(
            SAMPLE_RATE, AudioFormat.CHANNEL_IN_STEREO, AudioFormat.ENCODING_PCM_16BIT
        )
        val rec = AudioRecord.Builder()
            .setAudioFormat(format)
            .setBufferSizeInBytes(maxOf(minBuffer, CHUNK_BYTES * 4))
            .setAudioPlaybackCaptureConfig(config)
            .build()
        record = rec
        rec.startRecording()

        running = true
        thread = Thread {
            val buffer = ByteArray(CHUNK_BYTES)
            while (running) {
                var filled = 0
                while (running && filled < CHUNK_BYTES) {
                    val n = rec.read(buffer, filled, CHUNK_BYTES - filled)
                    if (n < 0) { CaptureBus.error("Falló la lectura de audio ($n)."); running = false; break }
                    filled += n
                }
                if (running && filled == CHUNK_BYTES) CaptureBus.pcm(buffer.copyOf())
            }
        }.also { it.name = "audioshare-capture"; it.start() }
    }

    private fun stopCapture() {
        running = false
        try { thread?.join(500) } catch (_: InterruptedException) {}
        thread = null
        try { record?.stop() } catch (_: Exception) {}
        record?.release(); record = null
        projection?.stop(); projection = null
    }

    override fun onDestroy() { stopCapture(); super.onDestroy() }

    private fun notification(): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, "Transmisión en vivo", NotificationManager.IMPORTANCE_LOW)
        )
        return Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("AudioShare está compartiendo audio")
            .setContentText("Abre la app para dejar de compartir.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build()
    }

    companion object {
        const val ACTION_STOP = "audioshare.STOP"
        const val EXTRA_CODE = "code"
        const val EXTRA_DATA = "data"
        const val EXTRA_UID = "uid"
        private const val CHANNEL_ID = "audioshare_live"
        private const val NOTIFICATION_ID = 41
        private const val SAMPLE_RATE = 48000
        private const val CHUNK_BYTES = 1024 * 2 * 2 // 1024 muestras x 2 canales x 2 bytes
    }
}
