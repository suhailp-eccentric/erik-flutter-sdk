
import 'erik_flutter_sdk_platform_interface.dart';

class ErikFlutterSdk {
  Future<String?> getPlatformVersion() {
    return ErikFlutterSdkPlatform.instance.getPlatformVersion();
  }
}
