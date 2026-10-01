import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Login opens and rejects empty credentials', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.byType(TextField), findsNWidgets(2));
    final login = find.text('로그인').last;
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pump();
    expect(find.text('아이디와 비밀번호를 입력해주세요.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
