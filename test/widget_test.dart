import 'package:flutter_test/flutter_test.dart';

import 'package:mindsieve/main.dart';

void main() {
  testWidgets('App starts with three bottom tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const MindSieveApp());

    // 验证底部三个 Tab 存在
    expect(find.text('主页'), findsOneWidget);
    expect(find.text('报告'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });
}
