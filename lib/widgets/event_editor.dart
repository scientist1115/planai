import 'package:flutter/material.dart';
import '../models.dart';
import '../utils.dart';

/// 일정 추가/수정 시트. 저장하면 수정된 PlanEvent를, 취소하면 null을 돌려줍니다.
Future<PlanEvent?> showEventEditor(BuildContext context, PlanEvent initial) {
  return showModalBottomSheet<PlanEvent>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EventEditor(initial: initial.copy()),
  );
}

class _EventEditor extends StatefulWidget {
  final PlanEvent initial;
  const _EventEditor({required this.initial});

  @override
  State<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<_EventEditor> {
  late final PlanEvent e = widget.initial;
  late final _title = TextEditingController(text: e.title);

  DateTime _withDate(DateTime t, DateTime d) => DateTime(d.year, d.month, d.day, t.hour, t.minute);
  DateTime _withTime(DateTime d, TimeOfDay t) => DateTime(d.year, d.month, d.day, t.hour, t.minute);

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: e.start,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() {
      e.start = _withDate(e.start, d);
      if (e.end != null) e.end = _withDate(e.end!, d);
    });
  }

  Future<void> _pickStart() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(e.start));
    if (t == null) return;
    setState(() {
      final dur = e.end?.difference(e.start);
      e.start = _withTime(e.start, t);
      if (dur != null) e.end = e.start.add(dur);
    });
  }

  Future<void> _pickEnd() async {
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(e.end ?? e.start.add(const Duration(hours: 1))),
    );
    if (t == null) return;
    setState(() {
      var end = _withTime(e.start, t);
      if (end.isBefore(e.start)) end = end.add(const Duration(days: 1));
      e.end = end;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(e.id == null ? '일정 확인' : '일정 수정', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            TextField(controller: _title, decoration: const InputDecoration(labelText: '무엇을 하나요?', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event, size: 18), label: Text(fmtDateShort(e.start))),
              OutlinedButton.icon(onPressed: _pickStart, icon: const Icon(Icons.schedule, size: 18), label: Text('시작 ${fmtTime(e.start)}')),
              OutlinedButton(onPressed: _pickEnd, child: Text(e.end == null ? '끝 시간 추가' : '끝 ${fmtTime(e.end!)}')),
            ]),
            const SizedBox(height: 16),
            Text('분류', style: t.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 6, children: [
              for (final c in kCategories)
                ChoiceChip(label: Text(c), selected: e.category == c, onSelected: (_) => setState(() => e.category = c)),
            ]),
            if (e.isStudy) ...[
              const SizedBox(height: 12),
              Text('과목', style: t.labelLarge),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: [
                for (final s in kSubjects)
                  ChoiceChip(label: Text(s), selected: e.subject == s, onSelected: (_) => setState(() => e.subject = s)),
              ]),
            ],
            const SizedBox(height: 16),
            Text('우선순위', style: t.labelLarge),
            const SizedBox(height: 6),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final q in [1, 2, 3, 4]) ButtonSegment(value: q, label: Text(kQuadrantLabels[q]!)),
              ],
              selected: {e.quadrant},
              onSelectionChanged: (s) => setState(() => e.quadrant = s.first),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  final title = _title.text.trim();
                  if (title.isEmpty) return;
                  e.title = title;
                  Navigator.pop(context, e);
                },
                child: const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
