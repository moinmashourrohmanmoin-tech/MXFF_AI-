package com.mxff.ai

import android.app.Service
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.IBinder
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * Floating overlay service with the two overlay orb states:
 *  - small: draggable 64dp orb, tap = open MXFF AI, long-press = hide
 *  - large: active assistant orb (170dp) + status line + close control
 */
class MxffOverlayService : Service() {

    private var wm: WindowManager? = null
    private var rootView: View? = null
    private var mode: String = "small"

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (Build.VERSION.SDK_INT >= 23 && !Settings.canDrawOverlays(this)) {
            stopSelf()
            return START_NOT_STICKY
        }
        val newMode = intent?.getStringExtra("mode") ?: mode
        val status = intent?.getStringExtra("status") ?: ""
        show(newMode, status)
        return START_STICKY
    }

    private fun dp(v: Int): Int =
        (v * resources.displayMetrics.density).toInt()

    private fun show(newMode: String, status: String) {
        mode = newMode
        (getSystemService(NOTIFICATION_SERVICE) as? android.app.NotificationManager)
            ?.cancel(MainActivity.RETURN_NOTIFICATION_ID)
        wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val type = overlayType()
        removeCurrent()
        if (mode == "large") showLarge(type, status) else showSmall(type)
    }

    private fun overlayType(): Int =
        if (Build.VERSION.SDK_INT >= 26)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else
            @Suppress("DEPRECATION") WindowManager.LayoutParams.TYPE_PHONE

    private fun removeCurrent() {
        rootView?.let {
            try {
                wm?.removeView(it)
            } catch (_: Exception) {
            }
        }
        rootView = null
    }

    // ------------------------------------------------------------------
    // Small floating orb (State B)
    // ------------------------------------------------------------------
    private fun showSmall(type: Int) {
        val container = FrameLayout(this)
        val orb = OrbView(this, big = false)
        val label = TextView(this).apply {
            text = "MXFF AI"
            textSize = 9f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }

        container.addView(
            orb,
            FrameLayout.LayoutParams(dp(64), dp(64), Gravity.CENTER)
        )
        container.addView(
            label,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT,
                FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER or Gravity.BOTTOM
            ).apply { bottomMargin = dp(14) }
        )

        container.background = GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(Color.argb(235, 4, 8, 10))
            setStroke(dp(2), Color.argb(200, 0, 245, 160))
        }

        val params = WindowManager.LayoutParams(
            dp(64), dp(64), type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(16)
            y = dp(220)
        }

        attachDrag(container, params) {
            openMxff()
        }
        container.setOnLongClickListener {
            stopSelf()
            true
        }

        addView(container, params)
    }

    // ------------------------------------------------------------------
    // Large active orb (State C)
    // ------------------------------------------------------------------
    private fun showLarge(type: Int, status: String) {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(12), dp(8), dp(12), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(240, 4, 8, 10))
                setStroke(dp(2), Color.argb(210, 0, 245, 160))
            }
        }

        val orb = OrbView(this, big = true)
        root.addView(orb, LinearLayout.LayoutParams(dp(150), dp(150)))

        val statusLabel = TextView(this).apply {
            text = status.ifEmpty { "MXFF AI is active…" }
            textSize = 12f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        root.addView(
            statusLabel,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(4) }
        )

        val close = TextView(this).apply {
            text = "✕"
            textSize = 13f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.argb(190, 255, 36, 73))
            }
        }

        val container = FrameLayout(this)
        container.addView(root)
        container.addView(
            close,
            FrameLayout.LayoutParams(dp(24), dp(24), Gravity.TOP or Gravity.END)
                .apply {
                    topMargin = dp(10)
                    marginEnd = dp(10)
                }
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT, type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.CENTER
        }

        close.setOnClickListener { show("small", "") }
        close.setOnLongClickListener {
            stopSelf()
            true
        }

        addView(container, params)
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    private fun addView(v: View, params: WindowManager.LayoutParams) {
        try {
            wm?.addView(v, params)
            rootView = v
        } catch (e: Exception) {
            stopSelf()
        }
    }

    private fun openMxff() {
        packageManager.getLaunchIntentForPackage(packageName)?.let {
            it.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            startActivity(it)
        }
    }

    private fun attachDrag(
        v: View,
        params: WindowManager.LayoutParams,
        onClick: () -> Unit
    ) {
        var downX = 0f
        var downY = 0f
        var startX = 0
        var startY = 0
        var moved = false
        v.setOnTouchListener { _, e ->
            when (e.action) {
                MotionEvent.ACTION_DOWN -> {
                    downX = e.rawX
                    downY = e.rawY
                    startX = params.x
                    startY = params.y
                    moved = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - downX).toInt()
                    val dy = (e.rawY - downY).toInt()
                    if (Math.abs(dx) > 10 || Math.abs(dy) > 10) {
                        moved = true
                        params.x = startX + dx
                        params.y = startY + dy
                        try {
                            wm?.updateViewLayout(v, params)
                        } catch (_: Exception) {
                        }
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    if (!moved) onClick()
                    true
                }
                else -> false
            }
        }
    }

    override fun onDestroy() {
        removeCurrent()
        wm = null
        super.onDestroy()
    }
}
