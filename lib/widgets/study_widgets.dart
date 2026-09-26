import 'package:flutter/material.dart';
import '../utils.dart';

List<Map<String, dynamic>> listOfMaps(dynamic v) =>
    ((v as List?) ?? []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

/// 영단어 플래시카드: 누르면 뒤집히고, '외웠어요' 표시·섞기 가능
class FlashcardsView extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  const FlashcardsView({super.key, required this.words});

  @override
  State<FlashcardsView> createState() => _FlashcardsViewState();
}

class _FlashcardsViewState extends State<FlashcardsView> {
  late final List<Map<String, dynamic>> _words = List.of(widget.words);
  final Set<String> _known = {};
  int _i = 0;
  bool _back = false;

  void _go(int i) => setState(() {
        _i = i;
        _back = false;
      });

  @override
  Widget build(BuildContext context) {
    if (_words.isEmpty) return const Center(child: Text('단어가 없어요'));
    final w = _words[_i];
    final word = (w['word'] ?? '') as String;
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    final front = Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(word, textAlign: TextAlign.center, style: t.displaySmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Text((w['part_of_speech'] ?? '') as String, style: t.titleMedium),
    ]);

    final back = ListView(children: [
      Text(word, style: t.titleMedium),
      const SizedBox(height: 4),
      Text((w['meaning'] ?? '') as String, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 16),
      Text((w['example'] ?? '') as String, style: t.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
      const SizedBox(height: 4),
      Text((w['example_ko'] ?? '') as String, style: t.bodyMedium),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kHighlighter.withAlpha(110), borderRadius: BorderRadius.circular(10)),
        child: Text('💡 ${(w['mnemonic'] ?? '') as String}', style: t.bodyLarge?.copyWith(color: Colors.black87)),
      ),
    ]);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        LinearProgressIndicator(value: (_i + 1) / _words.length),
        const SizedBox(height: 8),
        Text('${_i + 1} / ${_words.length}   외운 단어 ${_known.length}개'),
        const SizedBox(height: 16),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _back = !_back),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
              child: Card(
                key: ValueKey('$_i-$_back'),
                color: _back ? cs.secondaryContainer : cs.primaryContainer,
                child: SizedBox.expand(child: Padding(padding: const EdgeInsets.all(24), child: _back ? back : front)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('카드를 누르면 뜻이 나와요', style: t.bodySmall),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          IconButton.outlined(onPressed: _i > 0 ? () => _go(_i - 1) : null, icon: const Icon(Icons.chevron_left)),
          FilterChip(
            label: const Text('외웠어요'),
            selected: _known.contains(word),
            onSelected: (v) => setState(() => v ? _known.add(word) : _known.remove(word)),
          ),
          IconButton.outlined(
            tooltip: '섞기',
            onPressed: () => setState(() {
              _words.shuffle();
              _i = 0;
              _back = false;
            }),
            icon: const Icon(Icons.shuffle),
          ),
          IconButton.outlined(
            onPressed: _i < _words.length - 1 ? () => _go(_i + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
      ]),
    );
  }
}

class WordListView extends StatelessWidget {
  final List<Map<String, dynamic>> words;
  const WordListView({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: words.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (c, i) {
        final w = words[i];
        return ListTile(
          title: Text('${w['word'] ?? ''}  ${w['meaning'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('${w['example'] ?? ''}\n💡 ${w['mnemonic'] ?? ''}'),
          isThreeLine: true,
        );
      },
    );
  }
}

/// 4지선다 퀴즈
class QuizView extends StatefulWidget {
  final List<Map<String, dynamic>> quiz;
  const QuizView({super.key, required this.quiz});

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  int _i = 0;
  int? _picked;
  int _score = 0;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final quiz = widget.quiz;
    if (quiz.isEmpty) return const Center(child: Text('퀴즈가 없어요'));

    if (_i >= quiz.length) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(_score == quiz.length ? '🎉' : '💪', style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          Text('${quiz.length}문제 중 $_score개 맞았어요', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => setState(() {
              _i = 0;
              _picked = null;
              _score = 0;
            }),
            child: const Text('다시 풀기'),
          ),
        ]),
      );
    }

    final q = quiz[_i];
    final options = ((q['options'] as List?) ?? []).map((e) => e.toString()).toList();
    final answer = (q['answer'] as num?)?.toInt() ?? 0;

    Color? bg(int j) {
      if (_picked == null) return null;
      if (j == answer) return Colors.green.withAlpha(50);
      if (j == _picked) return Colors.red.withAlpha(50);
      return null;
    }

    return ListView(padding: const EdgeInsets.all(20), children: [
      Text('문제 ${_i + 1} / ${quiz.length}', style: t.labelLarge),
      const SizedBox(height: 8),
      Text((q['question'] ?? '') as String, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      for (var j = 0; j < options.length; j++)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: bg(j),
              padding: const EdgeInsets.all(14),
              alignment: Alignment.centerLeft,
            ),
            onPressed: () {
              if (_picked != null) return;
              setState(() {
                _picked = j;
                if (j == answer) _score++;
              });
            },
            child: Text('${j + 1}. ${options[j]}'),
          ),
        ),
      if (_picked != null) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_picked == answer ? '정답이에요!' : '정답은 ${answer + 1}번이에요',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text((q['explanation'] ?? '') as String),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(() {
            _i++;
            _picked = null;
          }),
          child: Text(_i == quiz.length - 1 ? '결과 보기' : '다음 문제'),
        ),
      ],
    ]);
  }
}

class SummaryView extends StatelessWidget {
  final String? summary;
  final List<String> items;
  const SummaryView({super.key, required this.summary, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      Text(summary ?? '', style: t.bodyLarge?.copyWith(height: 1.6)),
      const SizedBox(height: 16),
      for (final it in items)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              margin: const EdgeInsets.only(top: 7, right: 10),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(color: kInk, shape: BoxShape.circle),
            ),
            Expanded(child: Text(it, style: t.bodyLarge)),
          ]),
        ),
    ]);
  }
}

class TimelineView extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  const TimelineView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      itemCount: items.length,
      itemBuilder: (c, i) {
        final it = items[i];
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 86,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('${it['when'] ?? ''}', textAlign: TextAlign.right, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w800, color: kInk)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(children: [
                Container(width: 12, height: 12, decoration: const BoxDecoration(color: kHighlighter, shape: BoxShape.circle)),
                Expanded(child: Container(width: 2, color: i == items.length - 1 ? Colors.transparent : cs.outlineVariant)),
              ]),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Text('${it['what'] ?? ''}', style: t.bodyLarge),
              ),
            ),
          ]),
        );
      },
    );
  }
}

class SongView extends StatelessWidget {
  final Map<String, dynamic> song;
  const SongView({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(padding: const EdgeInsets.all(20), children: [
      if ((song['melody_hint'] ?? '').toString().isNotEmpty)
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: kHighlighter.withAlpha(110), borderRadius: BorderRadius.circular(10)),
          child: Text('🎵 ${song['melody_hint']}', style: t.bodyLarge?.copyWith(color: Colors.black87)),
        ),
      const SizedBox(height: 18),
      SelectableText((song['lyrics'] ?? '') as String, style: t.titleMedium?.copyWith(height: 1.8)),
      const SizedBox(height: 24),
      Text('소리 내어 3번 불러 보면 훨씬 오래 기억에 남아요.', style: t.bodySmall),
    ]);
  }
}
