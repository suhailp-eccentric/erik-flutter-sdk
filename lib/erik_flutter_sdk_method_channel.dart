import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'erik_flutter_sdk_platform_interface.dart';

/// An implementation of [ErikFlutterSdkPlatform] that uses method channels.
class MethodChannelErikFlutterSdk extends ErikFlutterSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('erik_flutter_sdk');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<bool> isEmulator() async {
    final result = await methodChannel.invokeMethod<bool>('isEmulator');
    return result ?? false;
  }
}
