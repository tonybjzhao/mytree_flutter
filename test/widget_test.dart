import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytree/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MyTree shows title and water button', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyTreeApp());

    // The screen contains a repeating sway animation, so `pumpAndSettle()`
    // would time out. Instead, pump a few frames for the async load to finish.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.text('Doing well 🌿').evaluate().isNotEmpty) break;
    }

    expect(find.text('MyTree'), findsOneWidget);
    expect(find.text('Water today'), findsOneWidget);
    expect(find.text('Doing well 🌿'), findsOneWidget);
  });
}
