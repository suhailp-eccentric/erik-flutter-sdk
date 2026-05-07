package com.eccentric.erik_flutter

import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class ErikPlatformViewFactory(
    private val messenger: BinaryMessenger,
    private val activityProvider: () -> FragmentActivity?,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(
        context: android.content.Context,
        viewId: Int,
        args: Any?,
    ): PlatformView = ErikPlatformView(context, messenger, viewId, activityProvider)
}
