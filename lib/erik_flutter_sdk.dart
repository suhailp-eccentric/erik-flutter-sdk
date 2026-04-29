export 'src/erik_view.dart';
import 'erik_flutter_sdk_platform_interface.dart';

class ErikFlutterSdk {
  Future<String?> getPlatformVersion() {
    return ErikFlutterSdkPlatform.instance.getPlatformVersion();
  }

  Future<bool> isEmulator() {
    return ErikFlutterSdkPlatform.instance.isEmulator();
  }
}
