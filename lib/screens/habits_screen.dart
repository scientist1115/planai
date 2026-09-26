import 'package:flutter/material.dart';
import '../models.dart';
import '../services/db.dart';
import '../utils.dart';

const _emojis = ['🏃', '📖', '💧', '🧘', '💪', '🎸', '✍️', '😴', '🥗', '🔤'];

/// 습관 트래커: 오늘 체크하면 달력에 ⭐가 붙어요
class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

class _HabitsScreenState extends State<HabitsScreen> {
  List<Habit> _habits = [];
  Map<String, int> _counts = {};
  Set<String> _today = {};

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
    final now = DateTime.now();
    try {
      final r = await Future.wait<dynamic>([
        Db.habits(),
        Db.habitCountsByHabit(DateTime(now.year, now.month, 1), now),
        Db.habitDoneIds(now),
      ]);
      if (!mounted) return;
      setState(() {
        _habits = r[0] as List<Habit>;
        _counts = r[1] as Map<String, int>;
        _today = r[2] as Set<String>;
      });
    } catch (_) {}
  }

  Future<void> _add() async {
    final name = TextEditingController();
    var emoji = _emojis.first;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('새 습관'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: name,
              autofocus: true,
              decoration: const InputDecoration(hintText: '예: 운동 30분, 영단어 30개'),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 4, children: [
              for (final e in _emojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 18)),
                  selected: emoji == e,
                  showCheckmark: false,
                  onSelected: (_) => setS(() => emoji = e),
                ),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('추가')),
          ],
        ),
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    await Db.addHabit(name.text.trim(), emoji);
  }

  Future<void> _delete(Habit h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('"${h.name}" 습관을 삭제할까요?'),
        content: const Text('지금까지의 기록도 함께 지워져요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok == true) await Db.deleteHabit(h.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final daysSoFar = DateTime.now().day;
    return Scaffold(
      appBar: AppBar(title: const Text('습관')),
      floatingActionButton: FloatingActionButton(onPressed: _add, tooltip: '습관 추가', child: const Icon(Icons.add)),
      body: _habits.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('매일 하고 싶은 일을 추가해 보세요.\n예: 운동, 독서, 물 2L 마시기\n\nAI 대화에서 "오늘 운동했어"라고 말해도 체크돼요.',
                    textAlign: TextAlign.center, style: t.bodyLarge),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text('오늘 체크하면 달력에 ⭐가 붙어요', style: t.bodyMedium),
                ),
                for (final h in _habits)
                  ListTile(
                    leading: Text(h.emoji, style: const TextStyle(fontSize: 28)),
                    title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: ((_counts[h.id] ?? 0) / daysSoFar).clamp(0.0, 1.0).toDouble(),
                        color: kInk,
                        backgroundColor: kHighlighter.withAlpha(70),
                      ),
                      const SizedBox(height: 4),
                      Text('이번 달 ${_counts[h.id] ?? 0}일 / $daysSoFar일'),
                    ]),
                    trailing: Checkbox(
                      value: _today.contains(h.id),
                      onChanged: (v) => Db.setHabit(h.id, DateTime.now(), v ?? false),
                    ),
                    onLongPress: () => _delete(h),
                  ),
              ],
            ),
    );
  }
}
