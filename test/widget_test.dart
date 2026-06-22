import 'package:flutter_test/flutter_test.dart';

import 'package:db_diff_tool/main.dart';

void main() {
  testWidgets('Home screen shows source/target pickers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DbCompareApp());

    expect(find.text('DB Compare Tool'), findsOneWidget);
    expect(find.text('Source'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    expect(find.text('Map Columns'), findsOneWidget);
  });
}
