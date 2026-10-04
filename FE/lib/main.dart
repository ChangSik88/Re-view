import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'review/design.dart';
import 'review/review_state.dart';
import 'review/diary_pages.dart';
import 'review/chat_page.dart';
import 'review/store_pages.dart';
import 'review/settings_page.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
      create: (_) => ReviewState(),
      child: MaterialApp(
        title: 'Re-view',
        debugShowCheckedModeBanner: false,
        theme: reviewTheme(),
        home: LoginScreen(),
        routes: {
          '/login': (_) => LoginScreen(),
          '/signup': (_) => SignUpScreen(),
          '/home': (_) => const HomePage(),
          '/dream_list': (_) => const DiaryHomePage(),
          '/store': (_) => const ShopPage(),
          '/settings': (_) => const SettingsPage(),
          '/notifications': (_) =>
              const InformationPage(title: '알림', text: '아직 도착한 알림이 없어요.'),
          '/preview': (_) => const StartPage(preview: true),
          '/start': (_) => const StartPage(),
          '/chat_input': (ctx) {
            final args = ModalRoute.of(ctx)?.settings.arguments as Map?;
            return ReviewChatPage(
                routine: args?['routine'] == 'night'
                    ? Routine.night
                    : Routine.morning);
          },
          '/routine_select': (_) => const DiaryHomePage(),
        },
      ));
}

class StartPage extends StatefulWidget {
  final bool preview;
  const StartPage({super.key, this.preview = false});
  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<ReviewState>().start(demo: widget.preview);
      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())));
}
