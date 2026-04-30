import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:erik_flutter_sdk_example/main.dart';

void main() {
  testWidgets('renders Tata EV details screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Vehicle Controls'), findsOneWidget);
    expect(
      find.text('Waiting for the 3D scene to finish loading.'),
      findsOneWidget,
    );
  });
}
