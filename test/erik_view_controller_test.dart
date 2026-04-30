import 'package:erik_flutter_sdk/erik_flutter_sdk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('marks intro animation start and completion', () {
    final controller = ErikViewController();
    var notifications = 0;

    controller.addListener(() {
      notifications += 1;
    });

    controller.markAnimationStarted();
    expect(controller.isIntroAnimationPlaying, isTrue);

    controller.markAnimationCompleted();
    expect(controller.isIntroAnimationPlaying, isFalse);
    expect(notifications, 2);
  });

  test('page start resets readiness and intro animation state', () {
    final controller = ErikViewController();

    controller.markBridgeReady();
    controller.markAnimationStarted();

    expect(controller.isReady, isTrue);
    expect(controller.isIntroAnimationPlaying, isTrue);

    controller.markPageStarted();

    expect(controller.isReady, isFalse);
    expect(controller.isIntroAnimationPlaying, isFalse);
  });
}
