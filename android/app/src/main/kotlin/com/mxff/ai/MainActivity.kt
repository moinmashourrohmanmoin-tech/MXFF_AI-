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

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
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
