import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../erik_flutter_sdk_platform_interface.dart';
import 'erik_asset_server.dart';
import 'erik_view_controller.dart';

class ErikView extends StatefulWidget {
  const ErikView({
    super.key,
    required this.controller,
    this.entryPoint = 'index.html',
    this.backgroundColor = Colors.black,
  });

  final ErikViewController controller;
  final String entryPoint;
  final Color backgroundColor;

  @override
  State<ErikView> createState() => _ErikViewState();
}

class _ErikViewState extends State<ErikView> {
  WebViewController? _controller;

  bool _isLoading = true;
  String? _errorMessage;

  bool get _supportsWebView => Platform.isAndroid || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    if (!_supportsWebView) {
      _isLoading = false;
      _errorMessage = 'ErikView is currently supported on Android and iOS.';
      return;
    }

    _prepareView();
  }

  Future<void> _prepareView() async {
    try {
      final isEmulator = await ErikFlutterSdkPlatform.instance.isEmulator();
      if (!mounted) return;

      if (Platform.isAndroid && isEmulator) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'ErikView needs a WebGL-capable device. This emulator does not expose the required OpenGL ES support for the bundled browser experience.';
        });
        return;
      }

      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(widget.backgroundColor)
        ..addJavaScriptChannel(
          'ErikBridge',
          onMessageReceived: (_) {
            widget.controller.markBridgeReady();
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              widget.controller.markPageStarted();
              if (!mounted) return;
              setState(() {
                _isLoading = true;
                _errorMessage = null;
              });
            },
            onPageFinished: (_) {
              widget.controller.markPageFinished();
              unawaited(
                _controller?.runJavaScript('''
(function waitForErikBridge() {
  if (typeof window.__erik !== 'undefined' &&
      typeof ErikBridge !== 'undefined') {
    ErikBridge.postMessage('ready');
    return;
  }
  setTimeout(waitForErikBridge, 250);
})();
'''),
              );
              if (!mounted) return;
              setState(() {
                _isLoading = false;
              });
            },
            onWebResourceError: (error) {
              if (!mounted) return;
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            },
          ),
        );

      widget.controller.attachWebViewController(_controller!);
      final url = await ErikAssetServer.instance.urlForEntryPoint(
        widget.entryPoint,
      );
      if (!mounted) return;
      await _controller!.loadRequest(url);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final webViewWidget = _controller == null
        ? null
        : WebViewWidget.fromPlatformCreationParams(
            params: _platformParamsForController(_controller!),
          );

    return DecoratedBox(
      decoration: BoxDecoration(color: widget.backgroundColor),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_errorMessage == null && webViewWidget != null) webViewWidget,
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
          if (_isLoading)
            const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
        ],
      ),
    );
  }

  PlatformWebViewWidgetCreationParams _platformParamsForController(
    WebViewController controller,
  ) {
    final params = PlatformWebViewWidgetCreationParams(
      controller: controller.platform,
      layoutDirection: TextDirection.ltr,
    );

    if (Platform.isAndroid) {
      return AndroidWebViewWidgetCreationParams.fromPlatformWebViewWidgetCreationParams(
        params,
        displayWithHybridComposition: true,
      );
    }

    return params;
  }
}
