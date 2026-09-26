import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models.dart';
import '../services/db.dart';
import '../services/notify.dart';
import '../utils.dart';
import '../widgets/event_editor.dart';
import 'day_detail_screen.dart';

/// 월간(조감도) · 2주 · 주간 보기. 날짜를 누르면 하루 상세(일간)로 들어가요.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime _selected = DateTime.now();
  CalendarFormat _format = CalendarFormat.month;
  Map<String, List<PlanEvent>> _byDay = {};
  Map<String, int> _habitCounts = {};
  List<PlanEvent> _keyEvents = [];

  @override
  void initState() {
    super.initState();
    _load();
    dataVersion.addListener(_load);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final first = DateTime(_focused.year, _focused.month, 1).subtract(const Duration(days: 7));
    final last = DateTime(_focused.year, _focused.month + 1, 1).add(const Duration(days: 7));
    try {
      final events = await Db.eventsBetween(first, last);
      final counts = await Db.habitCountsByDay(first, last);
      final map = <String, List<PlanEvent>>{};
      for (final e in events) {
        (map[dayKey(e.start)] ??= []).add(e);
      }
      if (!mounted) return;
      setState(() {
        _byDay = map;
        _habitCounts = counts;
        // 월간 조감도: 이번 달의 '중요' 일정(시험, 마감, 행사 등)
        _keyEvents = events.where((e) => e.start.month == _focused.month && e.quadrant <= 2).toList();
      });
    } catch (_) {}
  }

  void _openDay(DateTime day) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => DayDetailScreen(day: day)));
  }

  Future<void> _add() async {
    final now = DateTime.now();
    final base = DateTime(_selected.year, _selected.month, _selected.day, now.hour + 1);
    final e = await showEventEditor(context, PlanEvent(title: '', start: base, end: base.add(const Duration(hours: 1))));
    if (e == null) return;
    final saved = await Db.addEvent(e);
    await Notify.scheduleEvent(saved);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('달력')),
      floatingActionButton: FloatingActionButton(onPressed: _add, tooltip: '일정 추가', child: const Icon(Icons.add)),
      body: Column(children: [
        TableCalendar<PlanEvent>(
          locale: 'ko_KR',
          firstDay: DateTime.utc(2020, 1, 1),
          lastDay: DateTime.utc(2035, 12, 31),
          focusedDay: _focused,
          calendarFormat: _format,
          startingDayOfWeek: StartingDayOfWeek.sunday,
          availableCalendarFormats: const {
            CalendarFormat.month: '월간',
            CalendarFormat.twoWeeks: '2주',
            CalendarFormat.week: '주간',
          },
          headerStyle: const HeaderStyle(titleCentered: true, formatButtonShowsNext: false),
          calendarStyle: CalendarStyle(
            todayDecoration: const BoxDecoration(color: kHighlighter, shape: BoxShape.circle),
            todayTextStyle: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
            selectedDecoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
          ),
          eventLoader: (d) => _byDay[dayKey(d)] ?? const [],
          selectedDayPredicate: (d) => isSameDay(d, _selected),
          onDaySelected: (sel, foc) {
            setState(() {
              _selected = sel;
              _focused = foc;
            });
            _openDay(sel);
          },
          onFormatChanged: (f) => setState(() => _format = f),
          onPageChanged: (foc) {
            _focused = foc;
            _load();
          },
          calendarBuilders: CalendarBuilders<PlanEvent>(
            markerBuilder: (context, day, events) {
              final stars = _habitCounts[dayKey(day)] ?? 0;
              if (events.isEmpty && stars == 0) return null;
              return Positioned(
                bottom: 3,
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (final e in events.take(3))
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(color: quadrantColor(e.quadrant), shape: BoxShape.circle),
                    ),
                  if (stars > 0) const Text('⭐', style: TextStyle(fontSize: 8)),
                ]),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
          child: Row(children: [
            Text('${_focused.month}월에 놓치면 안 되는 일', style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          ]),
        ),
        Expanded(
          child: _keyEvents.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('시험, 마감, 행사처럼 중요한 일정이 여기에 모여요.\nAI 대화에서 "다음 주 금요일 수학 시험"처럼 말해 보세요.',
                        textAlign: TextAlign.center, style: t.bodyMedium),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: _keyEvents.length,
                  itemBuilder: (c, i) {
                    final e = _keyEvents[i];
                    return ListTile(
                      leading: Container(width: 4, height: 32, color: quadrantColor(e.quadrant)),
                      title: Text(e.title),
                      subtitle: Text('${fmtDateShort(e.start)} ${fmtRange(e)}'),
                      trailing: e.isStudy ? const Icon(Icons.school_outlined) : null,
                      onTap: () => _openDay(e.start),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
