package com.mxff.ai

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Bundle
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * User-enabled accessibility bridge. Operates on visible, exposed UI nodes only.
 * It deliberately does not inspect password fields or bypass secure windows.
 */
class MxffAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile var instance: MxffAccessibilityService? = null
        fun isEnabled(): Boolean = instance != null
    }

    override fun onServiceConnected() { instance = this }
    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() {}

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    fun global(action: String): Boolean = when (action.lowercase()) {
        "back" -> performGlobalAction(GLOBAL_ACTION_BACK)
        "home" -> performGlobalAction(GLOBAL_ACTION_HOME)
        "recents" -> performGlobalAction(GLOBAL_ACTION_RECENTS)
        "notifications" -> performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
        else -> false
    }

    fun clickText(target: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = root.findAccessibilityNodeInfosByText(target)
        for (node in nodes) {
            val clickable = clickableAncestor(node) ?: node
            if (clickable.isEnabled && clickable.isClickable) {
                val ok = clickable.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                if (ok) return true
            }
        }
        return false
    }

    fun setText(targetHint: String?, value: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val nodes = if (targetHint.isNullOrBlank()) listEditable(root)
                   else root.findAccessibilityNodeInfosByText(targetHint)
        for (node in nodes) {
            val editable = if (node.isEditable) node else findEditable(node)
            // Never type into password, PIN, OTP or other credential-like fields.
            if (editable != null && editable.isEnabled && !isSensitiveInput(editable)) {
                val args = Bundle().apply {
                    putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, value)
                }
                if (editable.performAction(AccessibilityNodeInfo.ACTION_FOCUS) &&
                    editable.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)) return true
            }
        }
        return false
    }

    fun scroll(direction: String): Boolean {
        val root = rootInActiveWindow ?: return false
        val action = if (direction.equals("up", true))
            AccessibilityNodeInfo.ACTION_SCROLL_BACKWARD
        else AccessibilityNodeInfo.ACTION_SCROLL_FORWARD
        return findScrollable(root)?.performAction(action) ?: false
    }

    private fun isSensitiveInput(node: AccessibilityNodeInfo): Boolean {
        if (node.isPassword) return true
        val hint = listOfNotNull(node.hintText?.toString(), node.text?.toString(),
            node.contentDescription?.toString(), node.viewIdResourceName).joinToString(" ").lowercase()
        return listOf("password", "passcode", "pin", "otp", "verification code",
            "পাসওয়ার্ড", "পাসওয়ার্ড", "পিন", "ওটিপি", "যাচাইকরণ কোড").any { hint.contains(it) }
    }

    fun visibleText(): String {
        val root = rootInActiveWindow ?: return ""
        val out = StringBuilder()
        fun walk(n: AccessibilityNodeInfo, depth: Int) {
            if (depth > 18 || out.length > 5000) return
            if (isSensitiveInput(n)) return
            val text = n.text?.toString()?.trim().orEmpty()
            val desc = n.contentDescription?.toString()?.trim().orEmpty()
            if (text.isNotEmpty()) out.append(text).append('\n')
            else if (desc.isNotEmpty()) out.append(desc).append('\n')
            for (i in 0 until n.childCount) n.getChild(i)?.let { walk(it, depth + 1) }
        }
        walk(root, 0)
        return out.toString().take(5000)
    }

    private fun clickableAncestor(start: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        var n: AccessibilityNodeInfo? = start
        repeat(8) {
            if (n?.isClickable == true) return n
            n = n?.parent
        }
        return null
    }
    private fun findEditable(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (n.isEditable) return n
        for (i in 0 until n.childCount) n.getChild(i)?.let { findEditable(it)?.let { found -> return found } }
        return null
    }
    private fun listEditable(n: AccessibilityNodeInfo): List<AccessibilityNodeInfo> {
        val out = mutableListOf<AccessibilityNodeInfo>()
        fun walk(x: AccessibilityNodeInfo) {
            if (x.isEditable) out.add(x)
            for (i in 0 until x.childCount) x.getChild(i)?.let { walk(it) }
        }
        walk(n); return out
    }
    private fun findScrollable(n: AccessibilityNodeInfo): AccessibilityNodeInfo? {
        if (n.isScrollable) return n
        for (i in 0 until n.childCount) n.getChild(i)?.let { findScrollable(it)?.let { found -> return found } }
        return null
    }
}
