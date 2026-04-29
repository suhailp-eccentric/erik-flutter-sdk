import 'package:flutter_test/flutter_test.dart';

import 'package:erik_flutter_sdk_example/main.dart';

void main() {
  testWidgets('renders Tata EV details screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Exterior View'), findsOneWidget);
    expect(find.text('Interior View'), findsOneWidget);
    expect(find.text('Toggle Doors'), findsOneWidget);
    expect(find.text('Toggle Lights'), findsOneWidget);
  });
}
