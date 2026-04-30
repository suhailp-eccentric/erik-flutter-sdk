import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum ErikDoor { frontLeft, frontRight, rearLeft, rearRight, boot, sunroof }

enum ErikVehicleView { exterior, interior }

enum ErikAnimationDirection { forward, reverse }

const List<String> erikAvailableColors = [
  'Rishikesh_Rapids',
  'Oxide',
  'Pure_Grey',
  'Coorg_Clouds',
  'Pristine_White',
  'Andaman_Adventure',
  'Nainital_Nocturne',
  'Bengal_Rouge_Tinted',
];

class ErikViewController extends ChangeNotifier {
  final Completer<WebViewController> _webViewControllerCompleter =
      Completer<WebViewController>();
  Completer<void> _pageFinishedCompleter = Completer<void>();

  bool _isReady = false;
  bool _isIntroAnimationPlaying = false;
  Future<void>? _bridgeAvailabilityFuture;

  bool get isReady => _isReady;
  bool get isIntroAnimationPlaying => _isIntroAnimationPlaying;

  Future<void> openDoor(ErikDoor door) {
    return playDoor(door, ErikAnimationDirection.forward);
  }

  Future<void> closeDoor(ErikDoor door) {
    return playDoor(door, ErikAnimationDirection.reverse);
  }

  Future<void> playDoor(ErikDoor door, ErikAnimationDirection direction) {
    return _runErikCommand(
      "__erik.play('${door._jsName}', '${direction.name}')",
    );
  }

  Future<void> openAllDoors() {
    return setAllDoorsOpen(true);
  }

  Future<void> closeAllDoors() {
    return setAllDoorsOpen(false);
  }

  Future<void> setAllDoorsOpen(bool open) {
    final direction = open
        ? ErikAnimationDirection.forward
        : ErikAnimationDirection.reverse;
    return _runErikCommand("__erik.allDoors('${direction.name}')");
  }

  Future<void> goToView(ErikVehicleView view) {
    final method = view == ErikVehicleView.interior
        ? '__erik.goInterior()'
        : '__erik.goExterior()';
    return _runErikCommand(method);
  }

  Future<void> goInterior() => goToView(ErikVehicleView.interior);

  Future<void> goExterior() => goToView(ErikVehicleView.exterior);

  Future<void> toggleLights() {
    return _runErikCommand('__erik.toggleLights()');
  }

  Future<void> setColor(String colorName) {
    final escapedColorName = colorName.replaceAll("'", r"\'");
    return _runErikCommand("__erik.setColor('$escapedColorName')");
  }

  Future<void> skipIntro() async {
    final wasPlaying = _isIntroAnimationPlaying;
    _setIntroAnimationPlaying(false);

    try {
      await _runErikCommand('__erik.skipIntro()');
    } catch (_) {
      if (wasPlaying) {
        _setIntroAnimationPlaying(true);
      }
      rethrow;
    }
  }

  Future<void> _runErikCommand(String command) async {
    final controller = await _webViewControllerCompleter.future;
    await _ensureBridgeReady(controller);
    final result = await controller.runJavaScriptReturningResult('''
(() => {
  try {
    $command;
    return 'ok';
  } catch (error) {
    return 'error:' + (error && error.message ? error.message : String(error));
  }
})()
''');

    final normalized = result.toString().replaceAll('"', '').trim();
    if (normalized.startsWith('error:')) {
      throw StateError(normalized.substring('error:'.length));
    }
  }

  Future<void> _ensureBridgeReady(WebViewController controller) async {
    if (_isReady) {
      return;
    }

    await _pageFinishedCompleter.future;
    _bridgeAvailabilityFuture ??= _waitForBridgeAvailability(controller);
    await _bridgeAvailabilityFuture;
  }

  Future<void> _waitForBridgeAvailability(WebViewController controller) async {
    const totalAttempts = 60;

    for (var attempt = 0; attempt < totalAttempts; attempt++) {
      final result = await controller.runJavaScriptReturningResult(
        "typeof window.__erik !== 'undefined'",
      );

      if (_isTruthyJsResult(result)) {
        _setReady(true);
        return;
      }

      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    throw StateError('Timed out waiting for the Erik JavaScript bridge.');
  }

  bool _isTruthyJsResult(Object result) {
    final normalized = result.toString().replaceAll('"', '').trim();
    return normalized == 'true';
  }

  void attachWebViewController(WebViewController controller) {
    if (!_webViewControllerCompleter.isCompleted) {
      _webViewControllerCompleter.complete(controller);
    }
  }

  void markPageStarted() {
    _bridgeAvailabilityFuture = null;
    _pageFinishedCompleter = Completer<void>();
    _setReady(false);
    _setIntroAnimationPlaying(false);
  }

  void markPageFinished() {
    _bridgeAvailabilityFuture = null;
    if (!_pageFinishedCompleter.isCompleted) {
      _pageFinishedCompleter.complete();
    }
    if (_webViewControllerCompleter.isCompleted) {
      unawaited(_ensureBridgeReadySync());
    }
  }

  void markBridgeReady() {
    _bridgeAvailabilityFuture = null;
    if (!_pageFinishedCompleter.isCompleted) {
      _pageFinishedCompleter.complete();
    }
    _setReady(true);
  }

  void markAnimationStarted() {
    _setIntroAnimationPlaying(true);
  }

  void markAnimationCompleted() {
    _setIntroAnimationPlaying(false);
  }

  Future<void> _ensureBridgeReadySync() async {
    try {
      final controller = await _webViewControllerCompleter.future;
      await _ensureBridgeReady(controller);
    } catch (_) {
      // Keep the controller usable even if initial boot takes longer.
    }
  }

  void _setReady(bool ready) {
    if (_isReady == ready) {
      return;
    }

    _isReady = ready;
    notifyListeners();
  }

  void _setIntroAnimationPlaying(bool playing) {
    if (_isIntroAnimationPlaying == playing) {
      return;
    }

    _isIntroAnimationPlaying = playing;
    notifyListeners();
  }
}

extension on ErikDoor {
  String get _jsName {
    switch (this) {
      case ErikDoor.frontLeft:
        return 'FRONT_LEFT_DOOR';
      case ErikDoor.frontRight:
        return 'FRONT_RIGHT_DOOR';
      case ErikDoor.rearLeft:
        return 'REAR_LEFT_DOOR';
      case ErikDoor.rearRight:
        return 'REAR_RIGHT_DOOR';
      case ErikDoor.boot:
        return 'BOOT_DOOR';
      case ErikDoor.sunroof:
        return 'SUNROOF_OPEN';
    }
  }
}
