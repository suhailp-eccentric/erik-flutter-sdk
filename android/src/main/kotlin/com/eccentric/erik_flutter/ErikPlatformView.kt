package com.eccentric.erik_flutter

import android.content.Context
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.TextView
import androidx.core.view.setPadding
import androidx.fragment.app.FragmentActivity
import androidx.fragment.app.FragmentContainerView
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

class ErikPlatformView(
    context: Context,
    messenger: BinaryMessenger,
    private val viewId: Int,
    private val activityProvider: () -> FragmentActivity?,
) : PlatformView,
    MethodChannel.MethodCallHandler,
    ErikFragment.Listener {
    private val channel = MethodChannel(messenger, "$VIEW_CHANNEL_PREFIX$viewId")
    private val containerView: View
    private val fragmentTag = "erik_flutter_sdk_fragment_$viewId"

    private var fragmentActivity: FragmentActivity? = null
    private var erikFragment: ErikFragment? = null
    private var disposed = false

    init {
        channel.setMethodCallHandler(this)
        containerView = attachOrCreateContainer(context)
        dispatchState(erikFragment?.currentState() ?: ErikRuntimeState())
    }

    override fun getView(): View = containerView

    override fun dispose() {
        disposed = true
        erikFragment?.setListener(null)
        channel.setMethodCallHandler(null)

        val activity = fragmentActivity
        val fragment = erikFragment
        if (activity != null && fragment != null) {
            activity.supportFragmentManager
                .beginTransaction()
                .remove(fragment)
                .commitNowAllowingStateLoss()
        }

        erikFragment = null
        fragmentActivity = null
    }

    override fun onMethodCall(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val fragment =
            erikFragment ?: run {
                result.error(
                    "fragment_unavailable",
                    "ErikFragment is unavailable. Ensure the host Activity extends FlutterFragmentActivity.",
                    null,
                )
                return
            }

        when (call.method) {
            "getState" -> result.success(fragment.currentState().toMap())
            "goExterior" -> fragment.goExterior(result.asCommandCallback())
            "goInterior" -> fragment.goInterior(result.asCommandCallback())
            "toggleLights" -> fragment.toggleLights(result.asCommandCallback())
            "setColor" -> {
                val colorName = call.arguments.asColorName()
                if (colorName == null) {
                    result.error("invalid_arguments", "Expected a non-empty color name.", null)
                } else {
                    fragment.setColor(colorName, result.asCommandCallback())
                }
            }
            "skipIntro" -> fragment.skipIntro(result.asCommandCallback())
            "openDoor" -> {
                val door = call.arguments.asDoor()
                if (door == null) {
                    result.error("invalid_arguments", "Expected a valid door name.", null)
                } else {
                    fragment.openDoor(door, result.asCommandCallback())
                }
            }
            "closeDoor" -> {
                val door = call.arguments.asDoor()
                if (door == null) {
                    result.error("invalid_arguments", "Expected a valid door name.", null)
                } else {
                    fragment.closeDoor(door, result.asCommandCallback())
                }
            }
            "setAllDoorsOpen" -> {
                val open = call.arguments.asOpenFlag()
                if (open == null) {
                    result.error("invalid_arguments", "Expected a boolean open flag.", null)
                } else {
                    fragment.setAllDoorsOpen(open, result.asCommandCallback())
                }
            }
            else -> result.notImplemented()
        }
    }

    override fun onStateChanged(state: ErikRuntimeState) {
        dispatchState(state)
    }

    private fun attachOrCreateContainer(context: Context): View {
        val activity = activityProvider()
        if (activity == null) {
            return TextView(context).apply {
                layoutParams =
                    ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                text =
                    "ErikFragment requires a FragmentActivity host. Use FlutterFragmentActivity in the Flutter example."
                setPadding(32)
            }
        }

        fragmentActivity = activity
        val containerId = VIEW_CONTAINER_BASE_ID + viewId
        val fragmentContainerView =
            FragmentContainerView(context).apply {
                id = containerId
                layoutParams =
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
            }

        val fragmentManager = activity.supportFragmentManager
        val existingFragment = fragmentManager.findFragmentByTag(fragmentTag) as? ErikFragment
        val fragment = existingFragment ?: ErikFragment()
        fragment.setListener(this)
        erikFragment = fragment

        if (existingFragment == null) {
            fragmentContainerView.replaceWithFragmentWhenAttached(containerId, fragment)
        }

        return fragmentContainerView
    }

    private fun FragmentContainerView.replaceWithFragmentWhenAttached(
        containerId: Int,
        fragment: ErikFragment,
    ) {
        if (isAttachedToWindow) {
            replaceWithFragment(containerId, fragment)
            return
        }

        addOnAttachStateChangeListener(
            object : View.OnAttachStateChangeListener {
                override fun onViewAttachedToWindow(view: View) {
                    removeOnAttachStateChangeListener(this)
                    replaceWithFragment(containerId, fragment)
                }

                override fun onViewDetachedFromWindow(view: View) = Unit
            },
        )
    }

    private fun replaceWithFragment(
        containerId: Int,
        fragment: ErikFragment,
    ) {
        val activity = fragmentActivity ?: return
        if (disposed || activity.supportFragmentManager.isDestroyed) {
            return
        }

        activity.supportFragmentManager
            .beginTransaction()
            .replace(containerId, fragment, fragmentTag)
            .commitNowAllowingStateLoss()
    }

    private fun dispatchState(state: ErikRuntimeState) {
        channel.invokeMethod("onStateChanged", state.toMap())
    }

    private fun MethodChannel.Result.asCommandCallback(): ErikCommandCallback =
        object : ErikCommandCallback {
            override fun onSuccess() {
                success(null)
            }

            override fun onError(message: String) {
                error("erik_command_failed", message, null)
            }
        }

    private fun ErikRuntimeState.toMap(): Map<String, Any> =
        mapOf(
            "isReady" to isReady,
            "isIntroAnimationPlaying" to isIntroAnimationPlaying,
        )

    private fun Any?.asColorName(): String? =
        when (this) {
            is String -> takeIf(String::isNotBlank)
            is Map<*, *> -> (this["color"] as? String)?.takeIf(String::isNotBlank)
            else -> null
        }

    private fun Any?.asOpenFlag(): Boolean? =
        when (this) {
            is Boolean -> this
            is Map<*, *> -> this["open"] as? Boolean
            else -> null
        }

    private fun Any?.asDoor(): ErikDoor? {
        val rawDoor =
            when (this) {
                is String -> this
                is Map<*, *> -> this["door"] as? String
                else -> null
            }

        return when (rawDoor) {
            "frontLeft" -> ErikDoor.FRONT_LEFT
            "frontRight" -> ErikDoor.FRONT_RIGHT
            "rearLeft" -> ErikDoor.REAR_LEFT
            "rearRight" -> ErikDoor.REAR_RIGHT
            "boot" -> ErikDoor.BOOT
            "sunroof" -> ErikDoor.SUNROOF
            else -> null
        }
    }

    companion object {
        const val VIEW_TYPE = "erik_flutter_sdk/erik_fragment_view"
        private const val VIEW_CHANNEL_PREFIX = "erik_flutter_sdk/view_"
        private const val VIEW_CONTAINER_BASE_ID = 47000
    }
}
