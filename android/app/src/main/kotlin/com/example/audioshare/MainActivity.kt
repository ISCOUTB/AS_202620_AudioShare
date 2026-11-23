package com.example.audioshare

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.media.projection.MediaProjectionConfig
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private var pendingUid: Int = -1
    private val playback = LivePlayback()

    private data class AppEntry(val label: String, val uid: Int)

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        EventChannel(messenger, "audioshare/capture/pcm").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, sink: EventChannel.EventSink?) {
                    CaptureBus.sink = sink
                }
                override fun onCancel(args: Any?) {
                    CaptureBus.sink = null
                }
            }
        )

        MethodChannel(messenger, "audioshare/playback").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    playback.start(call.argument<Int>("sampleRate") ?: 48000)
                    result.success(null)
                }
                "write" -> {
                    val pcm = call.argument<ByteArray>("pcm")
                    if (pcm == null) {
                        result.error("bad_args", "Falta el audio a reproducir.", null)
                    } else {
                        playback.write(
                            pcm,
                            call.argument<Int>("silenceMs") ?: 0,
                            call.argument<Boolean>("reset") ?: false,
                        )
                        result.success(null)
                    }
                }
                "volume" -> {
                    playback.setVolume((call.argument<Double>("volume") ?: 1.0).toFloat())
                    result.success(null)
                }
                "stop" -> {
                    playback.stop()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "audioshare/capture").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickApp" -> pickApp(result)
                "start" -> start(result, call.argument<Int>("uid") ?: -1)
                "stop" -> {
                    startService(Intent(this, CaptureService::class.java).setAction(CaptureService.ACTION_STOP))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        playback.stop()
        super.onDestroy()
    }

    /** Muestra la lista de apps instaladas y devuelve {uid, label} de la elegida. */
    private fun pickApp(result: MethodChannel.Result) {
        val launcher = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val pm = packageManager
        val apps = pm.queryIntentActivities(launcher, 0)
            .map { it.activityInfo.applicationInfo }
            .filter { it.packageName != packageName }
            .distinctBy { it.packageName }
            .map { AppEntry(it.loadLabel(pm).toString(), it.uid) }
            .sortedBy { it.label.lowercase() }

        if (apps.isEmpty()) {
            result.error("no-apps", "No encontré aplicaciones para elegir.", null)
            return
        }

        var done = false
        AlertDialog.Builder(this)
            .setTitle("¿De qué app quieres compartir el audio?")
            .setItems(apps.map { it.label }.toTypedArray()) { _, index ->
                done = true
                result.success(mapOf("uid" to apps[index].uid, "label" to apps[index].label))
            }
            .setNegativeButton("Cancelar", null)
            .setOnDismissListener {
                if (!done) {
                    done = true
                    result.error("cancelled", "No elegiste ninguna aplicación.", null)
                }
            }
            .create()
            .show()
    }

    private fun start(result: MethodChannel.Result, uid: Int) {
        if (pending != null) {
            result.error("busy", "Ya hay una solicitud de captura en curso.", null)
            return
        }
        pending = result
        pendingUid = uid
        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), REQ_AUDIO)
        } else {
            askProjection()
        }
    }

    private fun askProjection() {
        val manager = getSystemService(MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
        // Desde Android 14 se puede pedir solo «pantalla completa» y evitar el selector
        // de «una sola app», que confunde porque el audio se filtra aquí, no allí.
        val intent = if (Build.VERSION.SDK_INT >= 34) {
            manager.createScreenCaptureIntent(MediaProjectionConfig.createConfigForDefaultDisplay())
        } else {
            manager.createScreenCaptureIntent()
        }
        @Suppress("DEPRECATION")
        startActivityForResult(intent, REQ_PROJECTION)
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, perms, grants)
        if (code != REQ_AUDIO) return
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            askProjection()
        } else {
            finish(false, "denied", "Necesito el permiso de audio para compartir lo que suena en el celular.")
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PROJECTION) return
        if (resultCode == Activity.RESULT_OK && data != null) {
            val intent = Intent(this, CaptureService::class.java)
                .putExtra(CaptureService.EXTRA_CODE, resultCode)
                .putExtra(CaptureService.EXTRA_DATA, data)
                .putExtra(CaptureService.EXTRA_UID, pendingUid)
            startForegroundService(intent)
            finish(true, null, null)
        } else {
            finish(false, "denied", "Cancelaste el permiso de captura.")
        }
    }

    private fun finish(ok: Boolean, code: String?, message: String?) {
        val result = pending ?: return
        pending = null
        pendingUid = -1
        if (ok) result.success(null) else result.error(code ?: "error", message, null)
    }

    companion object {
        private const val REQ_AUDIO = 1001
        private const val REQ_PROJECTION = 1002
    }
}

/** Puente entre el servicio de captura y el EventChannel (siempre en el hilo principal). */
object CaptureBus {
    @Volatile var sink: EventChannel.EventSink? = null
    private val main = Handler(Looper.getMainLooper())

    fun pcm(bytes: ByteArray) { main.post { sink?.success(bytes) } }
    fun error(message: String) { main.post { sink?.error("capture", message, null) } }
}
