import 'package:flutter_test/flutter_test.dart';
import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
import 'package:erik_flutter_sdk/erik_flutter_sdk_platform_interface.dart';
import 'package:erik_flutter_sdk/erik_flutter_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockErikFlutterSdkPlatform
    with MockPlatformInterfaceMixin
    implements ErikFlutterSdkPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');

  @override
  Future<bool> isEmulator() => Future.value(false);
}

void main() {
  final ErikFlutterSdkPlatform initialPlatform =
      ErikFlutterSdkPlatform.instance;

  test('$MethodChannelErikFlutterSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelErikFlutterSdk>());
  });

  test('getPlatformVersion', () async {
    ErikFlutterSdk erikFlutterSdkPlugin = ErikFlutterSdk();
    MockErikFlutterSdkPlatform fakePlatform = MockErikFlutterSdkPlatform();
    ErikFlutterSdkPlatform.instance = fakePlatform;

    expect(await erikFlutterSdkPlugin.getPlatformVersion(), '42');
  });
}
