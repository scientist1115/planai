import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/db.dart';
import '../services/notify.dart';
import '../utils.dart';

const _grades = ['초등학생', '중1', '중2', '중3', '고1', '고2', '고3', '대학생', '직장인', '기타'];

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.onDone});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nick = TextEditingController(
    text: Supabase.instance.client.auth.currentUser?.userMetadata?['name']?.toString() ?? '',
  );
  final _goals = TextEditingController();
  final _guardian = TextEditingController();
  int? _birthYear;
  String? _grade;
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _sleep = const TimeOfDay(hour: 23, minute: 0);
  bool _guardianOk = false;
  bool _agree = false;
  bool _saving = false;

  /// 만 14세 미만일 가능성이 있으면 보호자 동의를 받습니다 (개인정보보호법 제22조의2)
  bool get _under14 => _birthYear != null && DateTime.now().year - _birthYear! <= 14;

  bool get _valid =>
      _nick.text.trim().isNotEmpty &&
      _birthYear != null &&
      _agree &&
      (!_under14 || (_guardianOk && _guardian.text.trim().isNotEmpty));

  Future<void> _pickTime(bool wake) async {
    final t = await showTimePicker(context: context, initialTime: wake ? _wake : _sleep);
    if (t != null) setState(() => wake ? _wake = t : _sleep = t);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await Db.saveProfile({
        'nickname': _nick.text.trim(),
        'birth_year': _birthYear,
        'grade': _grade,
        'wake_time': hm(_wake),
        'sleep_time': hm(_sleep),
        'goals': _goals.text.trim(),
        'guardian_consent': _under14 ? _guardianOk : false,
        'guardian_name': _under14 ? _guardian.text.trim() : null,
        'agreed_at': DateTime.now().toUtc().toIso8601String(),
        'onboarded': true,
      });
      await Notify.requestPermissions();
      await Notify.setBriefing(true, _wake.hour, _wake.minute);
      widget.onDone();
    } catch (e) {
      if (mounted) toast(context, '저장하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final thisYear = DateTime.now().year;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            Text('반가워요!', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('AI가 나한테 딱 맞게 시간을 배치할 수 있도록 몇 가지만 알려 주세요.', style: t.bodyLarge),
            const SizedBox(height: 28),
            TextField(
              controller: _nick,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: '닉네임', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _birthYear,
                  decoration: const InputDecoration(labelText: '출생 연도', border: OutlineInputBorder()),
                  items: [
                    for (var y = thisYear - 7; y >= thisYear - 70; y--)
                      DropdownMenuItem(value: y, child: Text('$y년')),
                  ],
                  onChanged: (v) => setState(() => _birthYear = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _grade,
                  decoration: const InputDecoration(labelText: '학년/신분', border: OutlineInputBorder()),
                  items: [for (final g in _grades) DropdownMenuItem(value: g, child: Text(g))],
                  onChanged: (v) => setState(() => _grade = v),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _TimeTile(label: '보통 일어나는 시간', time: _wake, onTap: () => _pickTime(true))),
              const SizedBox(width: 12),
              Expanded(child: _TimeTile(label: '보통 자는 시간', time: _sleep, onTap: () => _pickTime(false))),
            ]),
            const SizedBox(height: 14),
            TextField(
              controller: _goals,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '요즘 목표 (선택)',
                hintText: '예: 한국사능력검정 100점, 매일 영단어 30개',
                border: OutlineInputBorder(),
              ),
            ),
            if (_under14) ...[
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('보호자 동의가 필요해요', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('만 14세 미만은 법에 따라 보호자(부모님 등)의 동의를 받아야 서비스를 이용할 수 있어요.'),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _guardian,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(labelText: '보호자 이름', border: OutlineInputBorder()),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _guardianOk,
                      onChanged: (v) => setState(() => _guardianOk = v ?? false),
                      title: const Text('보호자가 개인정보 수집·이용에 동의했어요'),
                    ),
                  ]),
                ),
              ),
            ],
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _agree,
              onChanged: (v) => setState(() => _agree = v ?? false),
              title: const Text('(필수) 이용약관 및 개인정보 수집·이용에 동의'),
              subtitle: GestureDetector(
                onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl)),
                child: const Text('개인정보처리방침 보기', style: TextStyle(decoration: TextDecoration.underline)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _valid && !_saving ? _save : null,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('시작하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        child: Text(hm(time), style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
