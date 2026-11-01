package com.mxff.ai

import android.animation.ValueAnimator
import android.content.Context
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Shader
import android.util.AttributeSet
import android.view.animation.LinearInterpolator
import kotlin.math.cos
import kotlin.math.sin
import kotlin.random.Random

/**
 * Native animated MXFF orb: red energy core, green particles, rotating rings.
 * Used by the floating overlay service in both small and large modes.
 */
class OrbView @JvmOverloads constructor(
    context: Context,
    attrs: AttributeSet? = null,
    private val big: Boolean = false
) : android.view.View(context, attrs) {

    private data class Particle(
        val angle: Float,
        val dist: Float,     // 0..1 fraction of radius
        val size: Float,
        val green: Boolean,
        val speed: Float
    )

    private val particles: List<Particle>
    private var t = 0f

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG)
    private val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 2f
    }

    private val animator: ValueAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
        duration = 10000
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            t = it.animatedValue as Float
            invalidate()
        }
    }

    init {
        val rand = Random(8)
        val count = if (big) 130 else 80
        particles = List(count) {
            Particle(
                angle = rand.nextFloat() * 2f * Math.PI.toFloat(),
                dist = 0.22f + rand.nextFloat() * 0.9f,
                size = rand.nextFloat() * 2.4f + 1f,
                green = rand.nextFloat() < 0.6f,
                speed = 1f + rand.nextFloat()
            )
        }
        setLayerType(LAYER_TYPE_HARDWARE, null)
    }

    override fun onAttachedToWindow() {
        super.onAttachedToWindow()
        animator.start()
    }

    override fun onDetachedFromWindow() {
        animator.cancel()
        super.onDetachedFromWindow()
    }

    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        val cx = width / 2f
        val cy = height / 2f
        val r = width * 0.36f
        val twoPi = 2f * Math.PI.toFloat()

        // Outer glow
        glowPaint.shader = RadialGradient(
            cx, cy, r * 1.7f,
            intArrayOf(0x47FF2449.toInt(), 0x1A00F5A0, 0x00000000),
            floatArrayOf(0f, 0.5f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r * 1.7f, glowPaint)

        // Body
        paint.shader = RadialGradient(
            cx, cy, r,
            intArrayOf(0xFF16261F.toInt(), 0xFF050A08.toInt(), 0xFF000000.toInt()),
            floatArrayOf(0f, 0.6f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, r, paint)
        paint.shader = null

        // Particles
        for (p in particles) {
            val a = p.angle + t * twoPi * p.speed
            val d = r * p.dist
            val x = cx + cos(a) * d
            val y = cy + sin(a) * d * 0.92f
            paint.color = if (p.green) 0xE600F5A0.toInt() else 0xE6FF2449.toInt()
            canvas.drawCircle(x, y, p.size * (if (big) 1.25f else 1f), paint)
        }

        // Rotating rings
        val rings = if (big) 3 else 2
        for (i in 0 until rings) {
            canvas.save()
            canvas.rotate(t * 360f * (if (i % 2 == 0) 1f else -0.7f) + i * 55f, cx, cy)
            ringPaint.color = (if (i % 2 == 0) 0x8C00F5A0 else 0x8C00D9FF).toInt()
            val rx = r * (2.6f + i * 0.16f)
            val ry = r * (0.66f + i * 0.1f)
            canvas.save()
            canvas.translate(cx, cy)
            canvas.scale(1f, ry / rx)
            canvas.drawCircle(0f, 0f, rx, ringPaint)
            canvas.restore()
            canvas.restore()
        }

        // Pulsing red core
        val pulse = 0.06f * sin(t * twoPi * 3f)
        val coreR = r * (0.22f + pulse)
        paint.shader = RadialGradient(
            cx, cy, coreR,
            intArrayOf(0xFFFFFFFF.toInt(), 0xFFFF2449.toInt(), 0xFF660018.toInt()),
            floatArrayOf(0f, 0.55f, 1f),
            Shader.TileMode.CLAMP
        )
        canvas.drawCircle(cx, cy, coreR, paint)
        paint.shader = null
    }
}
