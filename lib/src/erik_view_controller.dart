import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  Completer<void> _platformViewCompleter = Completer<void>();
  Future<void>? _stateSyncFuture;
  MethodChannel? _channel;

  bool _isReady = false;
  bool _isIntroAnimationPlaying = false;

  bool get isReady => _isReady;
  bool get isIntroAnimationPlaying => _isIntroAnimationPlaying;

  Future<void> openDoor(ErikDoor door) {
    return playDoor(door, ErikAnimationDirection.forward);
  }

  Future<void> closeDoor(ErikDoor door) {
    return playDoor(door, ErikAnimationDirection.reverse);
  }

  Future<void> playDoor(ErikDoor door, ErikAnimationDirection direction) {
    return _invoke(
      direction == ErikAnimationDirection.forward ? 'openDoor' : 'closeDoor',
      {'door': door._jsName},
    );
  }

  Future<void> openAllDoors() {
    return setAllDoorsOpen(true);
  }

  Future<void> closeAllDoors() {
    return setAllDoorsOpen(false);
  }

  Future<void> setAllDoorsOpen(bool open) {
    return _invoke('setAllDoorsOpen', {'open': open});
  }

  Future<void> goToView(ErikVehicleView view) {
    return _invoke(
      view == ErikVehicleView.interior ? 'goInterior' : 'goExterior',
    );
  }

  Future<void> goInterior() => goToView(ErikVehicleView.interior);

  Future<void> goExterior() => goToView(ErikVehicleView.exterior);

  Future<void> toggleLights() {
    return _invoke('toggleLights');
  }

  Future<void> setColor(String colorName) {
    return _invoke('setColor', {'color': colorName});
  }

  Future<void> skipIntro() async {
    final wasPlaying = _isIntroAnimationPlaying;
    _setIntroAnimationPlaying(false);

    try {
      await _invoke('skipIntro');
    } catch (_) {
      if (wasPlaying) {
        _setIntroAnimationPlaying(true);
      }
      rethrow;
    }
  }

  void attachPlatformView(int viewId) {
    _channel?.setMethodCallHandler(null);
    _channel = MethodChannel('erik_flutter_sdk/view_$viewId');
    _channel!.setMethodCallHandler(_handlePlatformCall);
    if (_platformViewCompleter.isCompleted) {
      _platformViewCompleter = Completer<void>();
    }
    _platformViewCompleter.complete();
    _setReady(false);
    _setIntroAnimationPlaying(false);
    _stateSyncFuture = _syncState();
  }

  Future<void> detachPlatformView() async {
    _channel?.setMethodCallHandler(null);
    _channel = null;
    if (_platformViewCompleter.isCompleted) {
      _platformViewCompleter = Completer<void>();
    }
    _stateSyncFuture = null;
    _setReady(false);
    _setIntroAnimationPlaying(false);
  }

  Future<dynamic> _handlePlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onStateChanged':
        _applyState(call.arguments);
        return null;
      default:
        throw MissingPluginException(
          'Unknown ErikView callback ${call.method}',
        );
    }
  }

  Future<void> _syncState() async {
    final channel = await _requireChannel();
    final payload = await channel.invokeMethod<Object?>('getState');
    if (payload != null) {
      _applyState(payload);
    }
  }

  void _applyState(Object? payload) {
    final state = payload is Map<Object?, Object?> ? payload : null;
    _setReady(state?['isReady'] == true);
    _setIntroAnimationPlaying(state?['isIntroAnimationPlaying'] == true);
  }

  Future<MethodChannel> _requireChannel() async {
    await _platformViewCompleter.future;
    final channel = _channel;
    if (channel == null) {
      throw StateError('ErikView is not attached to a native Android view.');
    }
    return channel;
  }

  Future<void> _invoke(String method, [Object? arguments]) async {
    final channel = await _requireChannel();
    await _stateSyncFuture;
    await channel.invokeMethod<void>(method, arguments);
  }

  @override
  void dispose() {
    unawaited(detachPlatformView());
    super.dispose();
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
        return 'frontLeft';
      case ErikDoor.frontRight:
        return 'frontRight';
      case ErikDoor.rearLeft:
        return 'rearLeft';
      case ErikDoor.rearRight:
        return 'rearRight';
      case ErikDoor.boot:
        return 'boot';
      case ErikDoor.sunroof:
        return 'sunroof';
    }
  }
}
