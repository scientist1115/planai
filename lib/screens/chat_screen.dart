import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/notify.dart';
import '../utils.dart';
import '../widgets/event_editor.dart';
import '../widgets/report.dart';

class _Msg {
  final bool fromUser;
  final String text;
  final Uint8List? image;
  final List<PlanEvent> events;
  final List<String> habits;
  final Map<String, dynamic>? journal;
  bool applied = false;

  _Msg({
    required this.fromUser,
    required this.text,
    this.image,
    List<PlanEvent>? events,
    List<String>? habits,
    this.journal,
  })  : events = events ?? [],
        habits = habits ?? [];

  bool get hasProposal => events.isNotEmpty || habits.isNotEmpty || (journal != null && journal!.isNotEmpty);
}

/// 앱의 첫 화면. 말로 하면 AI가 일정/습관/하루 기록으로 바꿔서 제안하고, 확인하면 저장됩니다.
class ChatScreen extends StatefulWidget {
  final Profile profile;
  const ChatScreen({super.key, required this.profile});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgs = <_Msg>[];
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  Attachment? _image;
  bool _sending = false;
  bool _loading = true;

  static const _suggestions = [
    '오늘 하루 계획 짜줘',
    '이번 주 일정 정리해줘',
    '다음 주 시험 공부 계획 세워줘',
    '오늘 운동했어',
  ];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  _Msg get _greeting => _Msg(
        fromUser: false,
        text: '안녕하세요 ${widget.profile.nickname}님!\n'
            '할 일을 편하게 말해 주세요. 시간은 제가 알아서 정리해서 플래너에 넣어 드릴게요.\n\n'
            '예) "내일 4시 영어학원이고, 금요일까지 한국사 수행평가 준비해야 해"\n'
            '시간표나 공지 사진을 보내도 돼요 📷',
      );

  Future<void> _loadHistory() async {
    try {
      final rows = await Db.chatHistory();
      _msgs.addAll(rows.map((r) => _Msg(fromUser: r['role'] == 'user', text: (r['content'] ?? '') as String)));
    } catch (_) {}
    if (_msgs.isEmpty) _msgs.add(_greeting);
    if (mounted) setState(() => _loading = false);
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pickImage(ImageSource src) async {
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    setState(() => _image = Attachment(bytes, x.mimeType ?? mimeFromName(x.name), x.name));
  }

  void _attachMenu() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.photo_camera),
            title: const Text('사진 찍기'),
            subtitle: const Text('시간표, 공지문, 계획표'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.camera);
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('앨범에서 고르기'),
            onTap: () {
              Navigator.pop(ctx);
              _pickImage(ImageSource.gallery);
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if ((text.isEmpty && _image == null) || _sending) return;
    final img = _image;
    setState(() {
      _msgs.add(_Msg(fromUser: true, text: text.isEmpty ? '(사진)' : text, image: img?.bytes));
      _ctrl.clear();
      _image = null;
      _sending = true;
    });
    _toBottom();
    try {
      final r = await Ai.chat(text.isEmpty ? '이 사진에서 일정을 찾아 줘' : text, image: img);
      _msgs.add(_Msg(fromUser: false, text: r.reply, events: r.events, habits: r.habits, journal: r.journal));
    } catch (e) {
      _msgs.add(_Msg(fromUser: false, text: '연결에 문제가 생겨서 답하지 못했어요. 인터넷 연결을 확인하고 다시 보내 주세요.'));
    } finally {
      if (mounted) setState(() => _sending = false);
      _toBottom();
    }
  }

  /// 제안된 일정/습관/기록을 실제로 저장
  Future<void> _apply(_Msg m) async {
    try {
      for (final e in m.events) {
        final saved = await Db.addEvent(e);
        await Notify.scheduleEvent(saved);
      }
      if (m.habits.isNotEmpty) {
        final list = await Db.habits();
        for (final name in m.habits) {
          var h = list.where((x) => x.name == name).firstOrNull;
          h ??= await Db.addHabit(name, '✅');
          await Db.setHabit(h.id, DateTime.now(), true);
        }
      }
      final jn = m.journal;
      if (jn != null && jn.isNotEmpty) {
        final j = await Db.journal(DateTime.now());
        String? merge(String? old, Object? add) {
          final a = (add as String?)?.trim() ?? '';
          if (a.isEmpty) return old;
          return (old == null || old.isEmpty) ? a : '$old\n$a';
        }

        j.gratitude = merge(j.gratitude, jn['gratitude']);
        j.memo = merge(j.memo, jn['memo']);
        final mood = (jn['mood'] as num?)?.toInt();
        if (mood != null) j.mood = mood.clamp(1, 5).toInt();
        await Db.saveJournal(j);
      }
      setState(() => m.applied = true);
    } catch (e) {
      if (mounted) toast(context, '저장하지 못했어요: $e');
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대화 기록을 지울까요?'),
        content: const Text('플래너에 저장된 일정은 그대로 남아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok != true) return;
    await Db.clearChat();
    setState(() {
      _msgs
        ..clear()
        ..add(_greeting);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 플래너'),
        actions: [
          IconButton(icon: const Icon(Icons.delete_sweep_outlined), tooltip: '대화 기록 지우기', onPressed: _clear),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: _msgs.length + (_sending ? 1 : 0),
                  itemBuilder: (c, i) => i == _msgs.length ? const _Typing() : _bubble(_msgs[i]),
                ),
        ),
        if (!_loading && _msgs.length <= 2)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final s in _suggestions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(label: Text(s), onPressed: () => _send(s)),
                  ),
              ],
            ),
          ),
        _inputBar(),
      ]),
    );
  }

  Widget _bubble(_Msg m) {
    final cs = Theme.of(context).colorScheme;
    final maxW = MediaQuery.sizeOf(context).width * 0.82;
    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxW),
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: m.fromUser ? cs.primary : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(m.fromUser ? 18 : 4),
          bottomRight: Radius.circular(m.fromUser ? 4 : 18),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (m.image != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(m.image!, height: 160)),
          ),
        Text(m.text, style: TextStyle(color: m.fromUser ? cs.onPrimary : cs.onSurface, height: 1.4)),
      ]),
    );

    return Column(
      crossAxisAlignment: m.fromUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onLongPress: m.fromUser ? null : () => showReportDialog(context, source: 'chat', content: m.text),
          child: bubble,
        ),
        if (!m.fromUser && m.hasProposal) _proposal(m, maxW),
      ],
    );
  }

  /// AI가 제안한 일정 카드 — 확인하고 '모두 추가'를 눌러야 저장돼요
  Widget _proposal(_Msg m, double maxW) {
    final t = Theme.of(context).textTheme;
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      margin: const EdgeInsets.only(bottom: 10, top: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final e in List.of(m.events))
          Row(children: [
            Container(
              width: 4,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: quadrantColor(e.quadrant), borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                Text(
                  '${fmtDateShort(e.start)} ${fmtRange(e)}  ${e.isStudy ? '공부${e.subject != null ? '(${e.subject})' : ''}' : e.category}',
                  style: t.bodySmall,
                ),
              ]),
            ),
            if (!m.applied) ...[
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined, size: 20),
                tooltip: '고치기',
                onPressed: () async {
                  final r = await showEventEditor(context, e);
                  if (r != null) setState(() => m.events[m.events.indexOf(e)] = r);
                },
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 20),
                tooltip: '빼기',
                onPressed: () => setState(() => m.events.remove(e)),
              ),
            ],
          ]),
        if (m.habits.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('습관 체크: ${m.habits.join(', ')}', style: t.bodyMedium),
          ),
        if (m.journal != null && m.journal!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('오늘 기록에 저장: ${[
              m.journal!['gratitude'],
              m.journal!['memo'],
            ].whereType<String>().where((s) => s.isNotEmpty).join(' / ')}${m.journal!['mood'] != null ? ' (기분 ${m.journal!['mood']}/5)' : ''}', style: t.bodyMedium),
          ),
        const SizedBox(height: 10),
        if (m.applied)
          Row(children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 6),
            const Text('플래너에 저장했어요'),
          ])
        else if (m.hasProposal)
          FilledButton.icon(
            onPressed: () => _apply(m),
            icon: const Icon(Icons.add_task),
            label: Text(m.events.isEmpty ? '저장하기' : '${m.events.length}개 모두 추가'),
          ),
      ]),
    );
  }

  Widget _inputBar() {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_image != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Stack(children: [
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_image!.bytes, height: 64)),
                Positioned(
                  right: 0,
                  top: 0,
                  child: GestureDetector(
                    onTap: () => setState(() => _image = null),
                    child: const CircleAvatar(radius: 10, child: Icon(Icons.close, size: 14)),
                  ),
                ),
              ]),
            ),
          Row(children: [
            IconButton(icon: const Icon(Icons.add_photo_alternate_outlined), tooltip: '사진 보내기', onPressed: _attachMenu),
            Expanded(
              child: TextField(
                controller: _ctrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: '할 일을 말하듯 적어 보세요',
                  filled: true,
                  fillColor: cs.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(icon: const Icon(Icons.arrow_upward), onPressed: _sending ? null : () => _send()),
          ]),
        ]),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.all(10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('계획 정리하는 중…'),
        ]),
      ),
    );
  }
}
