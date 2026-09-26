import 'package:flutter/material.dart';
import '../models.dart';
import '../services/notify.dart';
import 'calendar_screen.dart';
import 'chat_screen.dart';
import 'habits_screen.dart';
import 'settings_screen.dart';

/// 하단 탭. 첫 화면(0번)이 AI 대화라서 앱을 열자마자 일정을 말할 수 있어요.
class HomeShell extends StatefulWidget {
  final Profile profile;
  const HomeShell({super.key, required this.profile});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;

  @override
  void initState() {
    super.initState();
    Notify.resyncUpcoming().catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _i,
        children: [
          ChatScreen(profile: widget.profile),
          const CalendarScreen(),
          const HabitsScreen(),
          SettingsScreen(profile: widget.profile),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (i) => setState(() => _i = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'AI 대화'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '달력'),
          NavigationDestination(icon: Icon(Icons.check_circle_outline), selectedIcon: Icon(Icons.check_circle), label: '습관'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '설정'),
        ],
      ),
    );
  }
}
