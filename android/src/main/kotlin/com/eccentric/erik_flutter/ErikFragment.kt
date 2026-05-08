package com.eccentric.erik_flutter

import android.annotation.SuppressLint
import android.graphics.Color
import android.os.Bundle
import android.util.Log
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.webkit.ConsoleMessage
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebSettings
import android.webkit.WebView
import android.widget.FrameLayout
import androidx.fragment.app.Fragment
import androidx.webkit.WebViewAssetLoader
import androidx.webkit.WebViewClientCompat
class ErikFragment : Fragment() {
    interface Listener {
        fun onStateChanged(state: ErikRuntimeState)
    }

    private val pendingCommands = mutableListOf<PendingCommand>()

    private var listener: Listener? = null
    private var webView: WebView? = null
    private var assetLoader: WebViewAssetLoader? = null
    private var isReady = false
    private var isIntroAnimationPlaying = false

    fun setListener(listener: Listener?) {
        this.listener = listener
        listener?.onStateChanged(currentState())
    }

    fun currentState(): ErikRuntimeState = ErikRuntimeState(isReady, isIntroAnimationPlaying)

    fun openDoor(
        door: ErikDoor,
        callback: ErikCommandCallback = ErikCommandCallback.NONE,
    ) {
        runCommand("__erik.play('${door.jsName}', 'forward')", callback)
    }

    fun closeDoor(
        door: ErikDoor,
        callback: ErikCommandCallback = ErikCommandCallback.NONE,
    ) {
        runCommand("__erik.play('${door.jsName}', 'reverse')", callback)
    }

    fun setAllDoorsOpen(
        open: Boolean,
        callback: ErikCommandCallback = ErikCommandCallback.NONE,
    ) {
        val direction = if (open) "forward" else "reverse"
        runCommand("__erik.allDoors('$direction')", callback)
    }

    fun goInterior(callback: ErikCommandCallback = ErikCommandCallback.NONE) {
        runCommand("__erik.goInterior()", callback)
    }

    fun goExterior(callback: ErikCommandCallback = ErikCommandCallback.NONE) {
        runCommand("__erik.goExterior()", callback)
    }

    fun toggleLights(callback: ErikCommandCallback = ErikCommandCallback.NONE) {
        runCommand("__erik.toggleLights()", callback)
    }

    fun setColor(
        colorName: String,
        callback: ErikCommandCallback = ErikCommandCallback.NONE,
    ) {
        val escapedColorName = colorName.replace("'", "\\'")
        runCommand("__erik.setColor('$escapedColorName')", callback)
    }

    fun skipIntro(callback: ErikCommandCallback = ErikCommandCallback.NONE) {
        runCommand("__erik.skipIntro()", callback)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.e(LOG_TAG, "onCreate")
        assetLoader =
            WebViewAssetLoader.Builder()
                .addPathHandler("/", ErikAssetPathHandler(requireContext()))
                .build()
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreateView(
        inflater: android.view.LayoutInflater,
        container: ViewGroup?,
        savedInstanceState: Bundle?,
    ): View {
        Log.e(LOG_TAG, "onCreateView")
        val context = requireContext()
        val frameLayout =
            FrameLayout(context).apply {
                layoutParams =
                    ViewGroup.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                setBackgroundColor(Color.BLACK)
            }

        val createdWebView =
            WebView(context).apply {
                layoutParams =
                    FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT,
                    )
                setBackgroundColor(Color.BLACK)
                overScrollMode = View.OVER_SCROLL_NEVER

                settings.apply {
                    javaScriptEnabled = true
                    domStorageEnabled = true
                    mediaPlaybackRequiresUserGesture = false
                    cacheMode = WebSettings.LOAD_DEFAULT
                    mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
                }

                addJavascriptInterface(ErikJavascriptBridge(::handleJavascriptMessage), JS_BRIDGE_NAME)
                webChromeClient = createWebChromeClient()
                webViewClient = createWebViewClient()
                setOnTouchListener { view, event ->
                    when (event.actionMasked) {
                        MotionEvent.ACTION_DOWN,
                        MotionEvent.ACTION_MOVE -> {
                            view.parent?.requestDisallowInterceptTouchEvent(true)
                        }

                        MotionEvent.ACTION_UP,
                        MotionEvent.ACTION_CANCEL -> {
                            view.parent?.requestDisallowInterceptTouchEvent(false)
                        }
                    }
                    false
                }
                loadUrl(ENTRYPOINT_URL)
                postDelayed({ logJavascriptState(this) }, 4000)
            }

        webView = createdWebView
        frameLayout.addView(createdWebView)
        return frameLayout
    }

    override fun onDestroyView() {
        failPendingCommands("Erik view was destroyed before the command completed.")
        webView?.removeJavascriptInterface(JS_BRIDGE_NAME)
        webView?.apply {
            stopLoading()
            webChromeClient = null
            destroy()
        }
        webView = null
        super.onDestroyView()
    }

    private fun createWebChromeClient(): WebChromeClient =
        object : WebChromeClient() {
            override fun onConsoleMessage(consoleMessage: ConsoleMessage): Boolean {
                val message = consoleMessage.message()
                Log.d(LOG_TAG, "console: ${consoleMessage.messageLevel()} ${consoleMessage.sourceId()}:${consoleMessage.lineNumber()} $message")
                when {
                    message.contains("Starting trailer camera") -> setIntroAnimationPlaying(true)
                    message.contains("Trailer camera sequence finished") -> setIntroAnimationPlaying(false)
                }
                return super.onConsoleMessage(consoleMessage)
            }
        }

    private fun createWebViewClient(): WebViewClientCompat =
        object : WebViewClientCompat() {
            override fun shouldInterceptRequest(
                view: WebView,
                request: WebResourceRequest,
            ): WebResourceResponse? = assetLoader?.shouldInterceptRequest(request.url)

            override fun onReceivedError(
                view: WebView,
                request: WebResourceRequest,
                error: androidx.webkit.WebResourceErrorCompat,
            ) {
                Log.e(
                    LOG_TAG,
                    "request error: ${request.url} code=${error.errorCode} description=${error.description}",
                )
                super.onReceivedError(view, request, error)
            }

            override fun onReceivedHttpError(
                view: WebView,
                request: WebResourceRequest,
                errorResponse: WebResourceResponse,
            ) {
                Log.e(
                    LOG_TAG,
                    "http error: ${request.url} status=${errorResponse.statusCode} reason=${errorResponse.reasonPhrase}",
                )
                super.onReceivedHttpError(view, request, errorResponse)
            }

            override fun onPageStarted(
                view: WebView,
                url: String?,
                favicon: android.graphics.Bitmap?,
            ) {
                Log.e(LOG_TAG, "page started: $url")
                setReady(false)
                setIntroAnimationPlaying(false)
                super.onPageStarted(view, url, favicon)
            }

            override fun onPageFinished(
                view: WebView,
                url: String?,
            ) {
                Log.d(LOG_TAG, "page finished: $url")
                injectBootstrapScript(view)
                super.onPageFinished(view, url)
            }
        }

    private fun handleJavascriptMessage(message: String) {
        Log.e(LOG_TAG, "bridge message: $message")
        if (message == "ready") {
            setReady(true)
            flushPendingCommands()
        }
    }

    private fun injectBootstrapScript(target: WebView) {
        target.evaluateJavascript(
            """
            (function bootstrapErikNativeBridge() {
              let attempts = 0;
              (function tick() {
                if (typeof window.__erik !== 'undefined' &&
                    window.$JS_BRIDGE_NAME &&
                    typeof window.$JS_BRIDGE_NAME.postMessage === 'function') {
                  window.$JS_BRIDGE_NAME.postMessage('ready');
                  return;
                }
                if (attempts++ < 60) {
                  setTimeout(tick, 250);
                }
              })();
            })();
            """.trimIndent(),
            null,
        )
    }

    private fun runCommand(
        command: String,
        callback: ErikCommandCallback,
    ) {
        val currentWebView = webView
        if (currentWebView == null) {
            pendingCommands += PendingCommand(command, callback)
            return
        }

        if (!isReady) {
            pendingCommands += PendingCommand(command, callback)
            return
        }

        evaluateCommand(currentWebView, command, callback)
    }

    private fun flushPendingCommands() {
        val currentWebView = webView ?: return
        if (!isReady || pendingCommands.isEmpty()) {
            return
        }

        val queuedCommands = pendingCommands.toList()
        pendingCommands.clear()
        queuedCommands.forEach { pending ->
            evaluateCommand(currentWebView, pending.command, pending.callback)
        }
    }

    private fun evaluateCommand(
        target: WebView,
        command: String,
        callback: ErikCommandCallback,
    ) {
        val wrappedCommand =
            """
            (function() {
              try {
                $command;
                return 'ok';
              } catch (error) {
                return 'error:' + (error && error.message ? error.message : String(error));
              }
            })();
            """.trimIndent()

        target.post {
            target.evaluateJavascript(wrappedCommand) { rawResult ->
                val normalizedResult = normalizeJavascriptResult(rawResult)
                if (normalizedResult.startsWith("error:")) {
                    callback.onError(normalizedResult.removePrefix("error:"))
                } else {
                    callback.onSuccess()
                }
            }
        }
    }

    private fun normalizeJavascriptResult(rawResult: String?): String {
        if (rawResult == null || rawResult == "null") {
            return ""
        }

        return rawResult
            .removeSurrounding("\"")
            .replace("\\\\", "\\")
            .replace("\\n", "\n")
            .replace("\\\"", "\"")
    }

    private fun failPendingCommands(message: String) {
        if (pendingCommands.isEmpty()) {
            return
        }

        val commandsToFail = pendingCommands.toList()
        pendingCommands.clear()
        commandsToFail.forEach { pending ->
            pending.callback.onError(message)
        }
    }

    private fun setReady(ready: Boolean) {
        if (isReady == ready) {
            return
        }

        isReady = ready
        dispatchState()
    }

    private fun setIntroAnimationPlaying(playing: Boolean) {
        if (isIntroAnimationPlaying == playing) {
            return
        }

        isIntroAnimationPlaying = playing
        dispatchState()
    }

    private fun dispatchState() {
        Log.e(LOG_TAG, "state ready=$isReady intro=$isIntroAnimationPlaying")
        listener?.onStateChanged(currentState())
    }

    private fun logJavascriptState(target: WebView) {
        target.evaluateJavascript(
            """
            JSON.stringify({
              readyState: document.readyState,
              href: window.location.href,
              title: document.title,
              hasErik: typeof window.__erik !== 'undefined',
              hasCanvas: !!document.querySelector('canvas'),
              bodyText: document.body ? document.body.innerText.slice(0, 200) : null
            })
            """.trimIndent(),
        ) { result ->
            Log.e(LOG_TAG, "js state: $result")
        }
    }

    private data class PendingCommand(
        val command: String,
        val callback: ErikCommandCallback,
    )

    private class ErikJavascriptBridge(
        private val onMessage: (String) -> Unit,
    ) {
        @JavascriptInterface
        fun postMessage(message: String) {
            onMessage(message)
        }
    }

    private class ErikAssetPathHandler(
        context: android.content.Context,
    ) : WebViewAssetLoader.PathHandler {
        private val assetManager = context.assets

        override fun handle(path: String): WebResourceResponse? {
            val normalizedPath =
                path
                    .trimStart('/')
                    .removePrefix("$ASSET_PATH/")
                    .ifEmpty { "index.html" }

            val assetPath = "$ASSET_PATH/$normalizedPath"
            val mimeType = normalizedPath.toMimeType()

            return try {
                val inputStream = assetManager.open(assetPath)
                WebResourceResponse(mimeType, null, inputStream)
            } catch (_: java.io.FileNotFoundException) {
                null
            }
        }

        private fun String.toMimeType(): String =
            when (substringAfterLast('.', "").lowercase()) {
                "html" -> "text/html"
                "css" -> "text/css"
                "js" -> "application/javascript"
                "json" -> "application/json"
                "wasm" -> "application/wasm"
                "png" -> "image/png"
                "jpg", "jpeg" -> "image/jpeg"
                "ico" -> "image/x-icon"
                "svg" -> "image/svg+xml"
                "ttf" -> "font/ttf"
                "woff" -> "font/woff"
                "woff2" -> "font/woff2"
                "mp4" -> "video/mp4"
                else -> "application/octet-stream"
            }
    }

    companion object {
        private const val ASSET_PATH = "erik_resources"
        private const val JS_BRIDGE_NAME = "ErikNativeBridge"
        private const val ENTRYPOINT_URL =
            "https://appassets.androidplatform.net/$ASSET_PATH/index.html"
        private const val LOG_TAG = "ErikFragment"
    }
}
