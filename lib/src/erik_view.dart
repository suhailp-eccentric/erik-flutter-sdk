import 'dart:io';

import 'package:flutter/material.dart';
import 'erik_view_controller.dart';

class ErikView extends StatefulWidget {
  const ErikView({super.key, required this.controller});

  final ErikViewController controller;

  @override
  State<ErikView> createState() => _ErikViewState();
}

class _ErikViewState extends State<ErikView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ErikView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) {
      return;
    }

    oldWidget.controller.removeListener(_handleControllerChanged);
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    widget.controller.detachPlatformView();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const DecoratedBox(
        decoration: BoxDecoration(color: Colors.black),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'ErikView currently uses native Android and iOS platform views.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: Colors.black),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (Platform.isAndroid)
            AndroidView(
              viewType: 'erik_flutter_sdk/erik_fragment_view',
              layoutDirection: TextDirection.ltr,
              onPlatformViewCreated: widget.controller.attachPlatformView,
            )
          else
            UiKitView(
              viewType: 'erik_flutter_sdk/erik_fragment_view',
              layoutDirection: TextDirection.ltr,
              onPlatformViewCreated: widget.controller.attachPlatformView,
            ),
          if (!widget.controller.isReady)
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
}
