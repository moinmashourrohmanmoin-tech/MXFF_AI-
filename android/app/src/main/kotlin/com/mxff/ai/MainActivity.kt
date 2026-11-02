package com.mxff.ai

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val RETURN_CHANNEL_ID = "mxff_return"
        const val RETURN_NOTIFICATION_ID = 4201
        const val EXTRA_SHOW_ORB = "mxff_show_orb"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleShowOrbIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleShowOrbIntent(intent)
    }

    /// Notification button "Orb দেখাও" starts this activity with EXTRA_SHOW_ORB.
    private fun handleShowOrbIntent(i: Intent?) {
        if (i == null || !i.getBooleanExtra(EXTRA_SHOW_ORB, false)) return
        i.removeExtra(EXTRA_SHOW_ORB) // handle only once
        if (!canDrawOverlays()) return
        try {
            startService(
                Intent(this, MxffOverlayService::class.java)
                    .putExtra("mode", "small")
                    .putExtra("status", "")
            )
        } catch (_: Exception) {
        }
    }

    private var audioTrack: android.media.AudioTrack? = null
    private val pcmExecutor = java.util.concurrent.Executors.newSingleThreadExecutor()

    /// Plays Gemini Live's 24 kHz 16-bit mono PCM replies.
    private fun setupPcmChannel(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.mxff.ai/pcm")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val rate = call.argument<Int>("rate") ?: 24000
                        pcmExecutor.execute { startTrack(rate) }
                        result.success(null)
                    }
                    "write" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data != null) {
                            pcmExecutor.execute { audioTrack?.write(data, 0, data.size) }
                        }
                        result.success(null)
                    }
                    "flush" -> {
                        pcmExecutor.execute {
                            audioTrack?.let {
                                it.pause()
                                it.flush()
                                it.play()
                            }
                        }
                        result.success(null)
                    }
                    "stop" -> {
                        pcmExecutor.execute { stopTrack() }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private var micRecord: android.media.AudioRecord? = null
    @Volatile private var micRunning = false
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())

    /// Streams microphone audio (16 kHz, 16-bit mono PCM) to Flutter.
    private fun setupMicChannel(engine: FlutterEngine) {
        EventChannel(engine.dartExecutor.binaryMessenger, "com.mxff.ai/mic")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    startMic(events)
                }

                override fun onCancel(arguments: Any?) {
                    stopMic()
                }
            })
    }

    private fun startMic(events: EventChannel.EventSink) {
        stopMic()
        val rate = 16000
        val minBuf = android.media.AudioRecord.getMinBufferSize(
            rate,
            android.media.AudioFormat.CHANNEL_IN_MONO,
            android.media.AudioFormat.ENCODING_PCM_16BIT
        )
        val bufSize = maxOf(minBuf, 3200)
        val rec = android.media.AudioRecord(
            android.media.MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            rate,
            android.media.AudioFormat.CHANNEL_IN_MONO,
            android.media.AudioFormat.ENCODING_PCM_16BIT,
            bufSize
        )
        if (rec.state != android.media.AudioRecord.STATE_INITIALIZED) {
            rec.release()
            mainHandler.post { events.error("mic", "Microphone could not start", null) }
            return
        }
        micRecord = rec
        micRunning = true
        rec.startRecording()
        Thread {
            val buf = ByteArray(bufSize)
            while (micRunning) {
                val n = rec.read(buf, 0, buf.size)
                if (n > 0) {
                    val chunk = buf.copyOf(n)
                    mainHandler.post {
                        if (micRunning) events.success(chunk)
                    }
                }
            }
        }.start()
    }

    private fun stopMic() {
        micRunning = false
        val rec = micRecord
        micRecord = null
        if (rec != null) {
            try {
                rec.stop()
            } catch (_: Exception) {
            }
            rec.release()
        }
    }

    private fun startTrack(rate: Int) {
        stopTrack()
        val minBuf = android.media.AudioTrack.getMinBufferSize(
            rate,
            android.media.AudioFormat.CHANNEL_OUT_MONO,
            android.media.AudioFormat.ENCODING_PCM_16BIT
        )
        val track = android.media.AudioTrack.Builder()
            .setAudioAttributes(
                android.media.AudioAttributes.Builder()
                    .setUsage(android.media.AudioAttributes.USAGE_MEDIA)
                    .setContentType(android.media.AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                android.media.AudioFormat.Builder()
                    .setEncoding(android.media.AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(rate)
                    .setChannelMask(android.media.AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(minBuf * 4)
            .setTransferMode(android.media.AudioTrack.MODE_STREAM)
            .build()
        track.play()
        audioTrack = track
    }

    private fun stopTrack() {
        val t = audioTrack
        audioTrack = null
        if (t != null) {
            try {
                t.stop()
            } catch (_: Exception) {
            }
            t.release()
        }
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        setupPcmChannel(engine)
        setupMicChannel(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "com.mxff.ai/bridge")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasOverlayPermission" -> result.success(canDrawOverlays())

                    "requestOverlayPermission" -> {
                        if (!canDrawOverlays()) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                            } catch (_: ActivityNotFoundException) {
                            }
                        }
                        result.success(null)
                    }

                    "showOverlay" -> {
                        if (!canDrawOverlays()) {
                            result.error("NO_PERMISSION", "Overlay permission not granted", null)
                            return@setMethodCallHandler
                        }
                        val mode = call.argument<String>("mode") ?: "small"
                        val status = call.argument<String>("status") ?: ""
                        val intent = Intent(this, MxffOverlayService::class.java)
                            .putExtra("mode", mode)
                            .putExtra("status", status)
                        try {
                            startService(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("START_FAILED", e.message, null)
                        }
                    }

                    "updateOverlayStatus" -> {
                        val status = call.argument<String>("status") ?: ""
                        startService(
                            Intent(this, MxffOverlayService::class.java)
                                .putExtra("mode", "large")
                                .putExtra("status", status)
                        )
                        result.success(null)
                    }

                    "hideOverlay" -> {
                        stopService(Intent(this, MxffOverlayService::class.java))
                        result.success(null)
                    }

                    "openApp" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        if (pkg.isBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val intent = pkg.split(",")
                            .map { it.trim() }
                            .filter { it.isNotEmpty() }
                            .mapNotNull { packageManager.getLaunchIntentForPackage(it) }
                            .firstOrNull()
                        if (intent == null) {
                            result.success(false)
                        } else {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (_: ActivityNotFoundException) {
                                result.success(false)
                            }
                        }
                    }

                    "isAppInstalled" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        result.success(
                            pkg.split(",").any { p ->
                                p.trim().isNotEmpty() &&
                                    packageManager.getLaunchIntentForPackage(p.trim()) != null
                            }
                        )
                    }

                    "minimizeApp" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }

                    "showReturnNotification" -> {
                        try {
                            showReturnNotification()
                        } catch (_: Exception) {
                            // Notification permission may be denied; the app still works.
                        }
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun canDrawOverlays(): Boolean =
        Build.VERSION.SDK_INT < 23 || Settings.canDrawOverlays(this)

    private fun pendingFlags(): Int =
        PendingIntent.FLAG_UPDATE_CURRENT or
            (if (Build.VERSION.SDK_INT >= 23) PendingIntent.FLAG_IMMUTABLE else 0)

    /// Persistent notification shown while the floating orb is hidden.
    /// Tap = open MXFF AI. "Orb দেখাও" = show the floating orb again.
    private fun showReturnNotification() {
        val nm = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(
                RETURN_CHANNEL_ID,
                "MXFF AI",
                NotificationManager.IMPORTANCE_LOW
            )
            channel.description = "Floating orb লুকানো থাকলে MXFF AI ফেরত আনার নোটিফিকেশন"
            nm.createNotificationChannel(channel)
        }

        val openIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
        }
        val openPi = PendingIntent.getActivity(this, 1, openIntent, pendingFlags())

        val showIntent = Intent(this, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            )
            putExtra(EXTRA_SHOW_ORB, true)
        }
        val showPi = PendingIntent.getActivity(this, 2, showIntent, pendingFlags())

        @Suppress("DEPRECATION")
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(this, RETURN_CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(android.R.drawable.ic_btn_speak_now)
            .setContentTitle("MXFF AI")
            .setContentText("Floating orb লুকানো আছে। ট্যাপ করে MXFF AI খুলুন।")
            .setContentIntent(openPi)
            .setOngoing(true)

        @Suppress("DEPRECATION")
        builder.addAction(
            Notification.Action.Builder(
                android.R.drawable.ic_menu_view,
                "Orb দেখাও",
                showPi
            ).build()
        )

        nm.notify(RETURN_NOTIFICATION_ID, builder.build())
    }
}

private fun String.isBlank(): Boolean = trim().isEmpty()
