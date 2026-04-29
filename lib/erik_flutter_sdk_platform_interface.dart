import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'erik_flutter_sdk_method_channel.dart';

abstract class ErikFlutterSdkPlatform extends PlatformInterface {
  /// Constructs a ErikFlutterSdkPlatform.
  ErikFlutterSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static ErikFlutterSdkPlatform _instance = MethodChannelErikFlutterSdk();

  /// The default instance of [ErikFlutterSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelErikFlutterSdk].
  static ErikFlutterSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ErikFlutterSdkPlatform] when
  /// they register themselves.
  static set instance(ErikFlutterSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
