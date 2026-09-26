import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../utils.dart';
import '../widgets/report.dart';
import '../widgets/study_widgets.dart';

/// 공부 일정 하나에 딸린 학습 자료 목록
class StudyScreen extends StatefulWidget {
  final PlanEvent event;
  const StudyScreen({super.key, required this.event});

  @override
  State<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends State<StudyScreen> {
  List<StudySet> _sets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await Db.studySets(widget.event.id!);
      if (mounted) setState(() => _sets = s);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _create() async {
    final set = await Navigator.push<StudySet>(
      context,
      MaterialPageRoute(builder: (_) => StudyCreatorScreen(event: widget.event)),
    );
    if (set == null || !mounted) return;
    await _load();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => StudyViewerScreen(set: set)));
  }

  Future<void> _delete(StudySet s) async {
    await Db.deleteStudySet(s.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.event.title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('AI로 학습 자료 만들기'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _sets.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.school_outlined, size: 56),
                      const SizedBox(height: 12),
                      Text('아직 학습 자료가 없어요', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      Text(
                        '영어는 단어 목록이나 교재 사진을, 한국사는 공부할 범위나 자료 파일을 주면 '
                        'AI가 외우기 쉬운 단어장·암기송·연표·퀴즈를 만들어 줘요.',
                        textAlign: TextAlign.center,
                      ),
                    ]),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  children: [
                    for (final s in _sets)
                      Card(
                        child: ListTile(
                          leading: Text(kStudyEmoji[s.kind] ?? '📘', style: const TextStyle(fontSize: 28)),
                          title: Text(s.title),
                          subtitle: Text('${kStudyKinds[s.kind]} · ${DateFormat('M/d HH:mm').format(s.createdAt)}'),
                          trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(s)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudyViewerScreen(set: s))),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// 학습 자료 만들기: 종류 선택 + 텍스트/사진/파일 입력
class StudyCreatorScreen extends StatefulWidget {
  final PlanEvent event;
  const StudyCreatorScreen({super.key, required this.event});

  @override
  State<StudyCreatorScreen> createState() => _StudyCreatorScreenState();
}

class _StudyCreatorScreenState extends State<StudyCreatorScreen> {
  late String _kind = _guessKind();
  final _text = TextEditingController();
  Attachment? _file;
  bool _busy = false;

  String _guessKind() {
    final s = '${widget.event.subject ?? ''} ${widget.event.title}';
    if (s.contains('영어') || s.toLowerCase().contains('english') || s.contains('단어')) return 'vocab';
    if (s.contains('한국사') || s.contains('역사') || s.contains('한능검')) return 'history';
    return 'general';
  }

  String get _hint {
    switch (_kind) {
      case 'vocab':
        return '외울 단어를 적어 주세요.\n예) abandon, benefit, curious …\n비워 두면 주제에 맞는 단어를 AI가 골라요.';
      case 'history':
        return '공부할 범위나 내용을 적어 주세요.\n예) 조선 전기 정치 — 태조부터 성종까지';
      default:
        return '공부할 내용이나 범위를 적어 주세요.';
    }
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 2000, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _file = Attachment(bytes, x.mimeType ?? mimeFromName(x.name), x.name));
  }

  Future<void> _pickFile() async {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'txt'],
      withData: true,
    );
    final f = r?.files.single;
    if (f == null || f.bytes == null) return;
    if (f.bytes!.length > 8 * 1024 * 1024) {
      if (mounted) toast(context, '8MB 이하 파일만 보낼 수 있어요');
      return;
    }
    setState(() => _file = Attachment(f.bytes!, mimeFromName(f.name), f.name));
  }

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final set = await Ai.makeStudy(event: widget.event, kind: _kind, text: _text.text.trim(), file: _file);
      if (mounted) Navigator.pop(context, set);
    } catch (e) {
      if (mounted) toast(context, '만들지 못했어요. 잠시 후 다시 시도해 주세요.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('학습 자료 만들기')),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('어떤 자료가 필요해요?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final k in kStudyKinds.keys)
                  ButtonSegment(value: k, label: Text(kStudyKinds[k]!)),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
            ),
            const SizedBox(height: 8),
            Text(
              switch (_kind) {
                'vocab' => '단어 카드(뜻·예문·연상 암기법) + 퀴즈',
                'history' => '핵심 요약 + 연표 + 외우기 쉬운 암기송 가사 + 퀴즈',
                _ => '핵심 요약 + 퀴즈',
              },
              style: t.bodySmall,
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _text,
              minLines: 5,
              maxLines: 12,
              decoration: InputDecoration(hintText: _hint, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            Text('자료 첨부 (선택)', style: t.labelLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('교재 찍기'),
              ),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('앨범'),
              ),
              OutlinedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('PDF·TXT 파일'),
              ),
            ]),
            if (_file != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: InputChip(
                  label: Text(_file!.name, overflow: TextOverflow.ellipsis),
                  avatar: const Icon(Icons.description_outlined, size: 18),
                  onDeleted: () => setState(() => _file = null),
                ),
              ),
            const SizedBox(height: 28),
            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(_busy ? '만드는 중… (20~40초)' : '만들기'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 만들어진 학습 자료 보기 (종류별 탭)
class StudyViewerScreen extends StatelessWidget {
  final StudySet set;
  const StudyViewerScreen({super.key, required this.set});

  @override
  Widget build(BuildContext context) {
    final c = set.content;
    final quiz = listOfMaps(c['quiz']);
    final List<(String, Widget)> tabs;
    switch (set.kind) {
      case 'vocab':
        final words = listOfMaps(c['words']);
        tabs = [
          ('카드', FlashcardsView(words: words)),
          ('목록', WordListView(words: words)),
          ('퀴즈', QuizView(quiz: quiz)),
        ];
        break;
      case 'history':
        tabs = [
          ('요약', SummaryView(summary: c['summary'] as String?, items: _keywordLines(c['keywords']))),
          ('연표', TimelineView(items: listOfMaps(c['timeline']))),
          ('암기송', SongView(song: c['song'] is Map ? Map<String, dynamic>.from(c['song'] as Map) : const {})),
          ('퀴즈', QuizView(quiz: quiz)),
        ];
        break;
      default:
        tabs = [
          ('요약', SummaryView(summary: c['summary'] as String?, items: ((c['key_points'] as List?) ?? []).map((e) => e.toString()).toList())),
          ('퀴즈', QuizView(quiz: quiz)),
        ];
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(set.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              tooltip: '내용 신고',
              onPressed: () => showReportDialog(context, source: 'study:${set.id}', content: set.title),
            ),
          ],
          bottom: TabBar(tabs: [for (final tab in tabs) Tab(text: tab.$1)]),
        ),
        body: TabBarView(children: [for (final tab in tabs) tab.$2]),
      ),
    );
  }

  static List<String> _keywordLines(dynamic v) =>
      listOfMaps(v).map((m) => '${m['term'] ?? ''} — ${m['desc'] ?? ''}').toList();
}
