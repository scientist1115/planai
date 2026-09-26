import 'package:flutter/material.dart';
import '../models.dart';
import '../services/db.dart';
import '../services/notify.dart';
import '../utils.dart';
import '../widgets/event_editor.dart';
import 'habits_screen.dart';
import 'study_screen.dart';

const _moods = ['😢', '😕', '😐', '🙂', '😄'];

/// 하루 상세(일간): 일정 · 우선순위 매트릭스 · 습관 · 메모 · 감사일기/기분
/// 공부 일정 옆 [학습] 버튼 → AI 학습 시스템
class DayDetailScreen extends StatefulWidget {
  final DateTime day;
  const DayDetailScreen({super.key, required this.day});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  List<PlanEvent> _events = [];
  List<Habit> _habits = [];
  Set<String> _done = {};
  DayJournal? _journal;
  final _memo = TextEditingController();
  final _grat = TextEditingController();
  int? _mood;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    try {
      final r = await Future.wait<dynamic>([
        Db.eventsOnDay(widget.day),
        Db.habits(),
        Db.habitDoneIds(widget.day),
        Db.journal(widget.day),
      ]);
      if (!mounted) return;
      final j = r[3] as DayJournal;
      setState(() {
        _events = r[0] as List<PlanEvent>;
        _habits = r[1] as List<Habit>;
        _done = r[2] as Set<String>;
        _journal = j;
        _memo.text = j.memo ?? '';
        _grat.text = j.gratitude ?? '';
        _mood = j.mood;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        toast(context, '불러오지 못했어요: $e');
      }
    }
  }

  Future<void> _reloadEvents() async {
    final ev = await Db.eventsOnDay(widget.day);
    if (mounted) setState(() => _events = ev);
  }

  Future<void> _addEvent() async {
    final d = widget.day;
    final start = DateTime(d.year, d.month, d.day, 9);
    final e = await showEventEditor(context, PlanEvent(title: '', start: start, end: start.add(const Duration(hours: 1))));
    if (e == null) return;
    final saved = await Db.addEvent(e);
    await Notify.scheduleEvent(saved);
    await _reloadEvents();
  }

  Future<void> _editEvent(PlanEvent e) async {
    final r = await showEventEditor(context, e);
    if (r == null) return;
    await Db.updateEvent(r);
    await Notify.cancelEvent(r.id!);
    await Notify.scheduleEvent(r);
    await _reloadEvents();
  }

  Future<void> _deleteEvent(PlanEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${e.title}" 일정을 삭제할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await Db.deleteEvent(e.id!);
    await Notify.cancelEvent(e.id!);
    await _reloadEvents();
  }

  Future<void> _saveJournal() async {
    final j = _journal ?? DayJournal(day: dayKey(widget.day));
    j.memo = _memo.text.trim();
    j.gratitude = _grat.text.trim();
    j.mood = _mood;
    try {
      await Db.saveJournal(j);
      if (mounted) {
        FocusScope.of(context).unfocus();
        toast(context, '오늘 기록을 저장했어요');
      }
    } catch (e) {
      if (mounted) toast(context, '저장하지 못했어요: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fmtDateLong(widget.day))),
      floatingActionButton: FloatingActionButton(onPressed: _addEvent, tooltip: '일정 추가', child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              children: [
                _Section(title: '오늘의 일정', child: _eventList()),
                _Section(title: '우선순위', child: _matrix()),
                _Section(title: '습관 체크', child: _habitChips()),
                _Section(
                  title: '메모 · 브레인 덤프',
                  child: TextField(
                    controller: _memo,
                    minLines: 3,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      hintText: '떠오르는 생각, 아이디어, 연락할 사람…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                _Section(title: '오늘의 마음', child: _mindset()),
                const SizedBox(height: 8),
                FilledButton.icon(onPressed: _saveJournal, icon: const Icon(Icons.save_outlined), label: const Text('기록 저장')),
              ],
            ),
    );
  }

  Widget _eventList() {
    final t = Theme.of(context).textTheme;
    if (_events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('일정이 없어요. AI 대화에서 말하거나 + 버튼으로 추가해 보세요.', style: t.bodyMedium),
      );
    }
    return Column(children: [
      for (final e in _events)
        InkWell(
          onTap: () => _editEvent(e),
          onLongPress: () => _deleteEvent(e),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Checkbox(
                value: e.done,
                onChanged: (v) async {
                  e.done = v ?? false;
                  setState(() {});
                  await Db.updateEvent(e);
                  if (e.done) await Notify.cancelEvent(e.id!);
                },
              ),
              Container(
                width: 4,
                height: 34,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(color: quadrantColor(e.quadrant), borderRadius: BorderRadius.circular(2)),
              ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    e.title,
                    style: t.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      decoration: e.done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    '${fmtRange(e)}  ${e.isStudy ? '공부${e.subject != null ? '(${e.subject})' : ''}' : e.category}',
                    style: t.bodySmall,
                  ),
                ]),
              ),
              if (e.isStudy)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyScreen(event: e))),
                  icon: const Icon(Icons.school, size: 18),
                  label: const Text('학습'),
                ),
            ]),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('누르면 수정, 길게 누르면 삭제', style: t.bodySmall),
      ),
    ]);
  }

  /// 중요/급함 4칸 매트릭스
  Widget _matrix() {
    final t = Theme.of(context).textTheme;
    Widget cell(int q) {
      final items = _events.where((e) => e.quadrant == q).toList();
      final c = quadrantColor(q);
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.withAlpha(24),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: c, width: 3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(kQuadrantLabels[q]!, style: t.labelLarge?.copyWith(color: c, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (items.isEmpty) Text('-', style: t.bodySmall),
          for (final e in items.take(4))
            Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodySmall),
        ]),
      );
    }

    return Column(children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: cell(1)),
        const SizedBox(width: 8),
        Expanded(child: cell(2)),
      ]),
      const SizedBox(height: 8),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: cell(3)),
        const SizedBox(width: 8),
        Expanded(child: cell(4)),
      ]),
    ]);
  }

  Widget _habitChips() {
    if (_habits.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitsScreen()));
            _loadAll();
          },
          icon: const Icon(Icons.add),
          label: const Text('매일 하고 싶은 습관을 추가해 보세요'),
        ),
      );
    }
    return Wrap(spacing: 8, runSpacing: 4, children: [
      for (final h in _habits)
        FilterChip(
          label: Text('${h.emoji} ${h.name}'),
          selected: _done.contains(h.id),
          onSelected: (v) async {
            setState(() => v ? _done.add(h.id) : _done.remove(h.id));
            await Db.setHabit(h.id, widget.day, v);
          },
        ),
    ]);
  }

  Widget _mindset() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 5; i++)
          ChoiceChip(
            label: Text(_moods[i], style: const TextStyle(fontSize: 20)),
            selected: _mood == i + 1,
            showCheckmark: false,
            onSelected: (s) => setState(() => _mood = s ? i + 1 : null),
          ),
      ]),
      const SizedBox(height: 10),
      TextField(
        controller: _grat,
        minLines: 2,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: '감사한 일',
          hintText: '오늘 고마웠던 일 1~3가지',
          border: OutlineInputBorder(),
        ),
      ),
    ]);
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }
}
