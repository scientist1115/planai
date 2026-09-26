import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'models.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/db.dart';
import 'services/notify.dart';
import 'utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabaseAnonKey);
  await Notify.init();
  runApp(const PlanAIApp());
}

ThemeData _theme(Brightness b) {
  final scheme = ColorScheme.fromSeed(seedColor: kInk, brightness: b).copyWith(
    tertiary: kHighlighter,
    onTertiary: Colors.black87,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: b == Brightness.light ? Colors.white : null,
    appBarTheme: const AppBarTheme(centerTitle: false),
  );
}

class PlanAIApp extends StatelessWidget {
  const PlanAIApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanAI',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ko', 'KR'),
      supportedLocales: const [Locale('ko', 'KR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const AuthGate(),
    );
  }
}

/// 로그인 안 됨 → 로그인 화면 / 로그인 됨 → 프로필 확인
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) return const LoginScreen();
        return ProfileGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// 온보딩 전 → 온보딩 / 완료 → 홈(첫 화면은 AI 대화)
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late Future<Profile?> _future = Db.getProfile();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('정보를 불러오지 못했어요. 인터넷 연결을 확인해 주세요.'),
                TextButton(onPressed: () => setState(() => _future = Db.getProfile()), child: const Text('다시 시도')),
              ]),
            ),
          );
        }
        final p = snap.data;
        if (p == null || !p.onboarded) {
          return OnboardingScreen(onDone: () => setState(() => _future = Db.getProfile()));
        }
        return HomeShell(profile: p);
      },
    );
  }
}
