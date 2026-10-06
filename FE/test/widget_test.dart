import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:frontend/review/review_state.dart';

class RestoredState extends ReviewState {
  bool? restored;
  @override
  Future<void> start({bool demo = false, bool asGuest = false}) async {
    restored = !demo && !asGuest;
    guest = asGuest;
  }
}

void main() {
  testWidgets('Remembered session restores authenticated home', (tester) async {
    SharedPreferences.setMockInitialValues(
        {'auto_login': true, 'jwt_token': 'saved-session', 'user_id': 'user'});
    final state = RestoredState();
    await tester.pumpWidget(ChangeNotifierProvider<ReviewState>.value(
        value: state, child: const MaterialApp(home: AppEntryPage())));
    await tester.pumpAndSettle();
    expect(state.restored, isTrue);
    expect(find.text('꿈 기록하기'), findsOneWidget);
    expect(find.text('로그인'), findsNothing);
  });
  testWidgets('Unchecked previous session returns to guest home',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'auto_login': false,
      'jwt_token': 'old-session',
      'user_id': 'previous-user'
    });
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    expect(find.text('로그인'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('jwt_token'), isNull);
    expect(prefs.getString('user_id'), isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Guest home opens login and rejects empty credentials',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(MyApp());
    await tester.pumpAndSettle();
    expect(find.text('회원가입'), findsOneWidget);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('자동로그인'), findsOneWidget);
    final login = find.text('로그인').last;
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pump();
    expect(find.text('아이디와 비밀번호를 입력해주세요.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
