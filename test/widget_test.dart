import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mytree/main.dart';
import 'package:mytree/tree_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MyTree shows title and water button', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final treeService = await TreeService.create();

    await tester.pumpWidget(MyTreeApp(treeService: treeService));
    await tester.pumpAndSettle();

    expect(find.text('MyTree'), findsOneWidget);
    expect(find.text('Water today'), findsOneWidget);
    expect(find.textContaining('Status:'), findsOneWidget);
  });
}
