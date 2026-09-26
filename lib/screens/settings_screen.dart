import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../models.dart';
import '../services/auth.dart';
import '../services/db.dart';
import '../services/notify.dart';
import '../utils.dart';

class SettingsScreen extends StatefulWidget {
  final Profile profile;
  const SettingsScreen({super.key, required this.profile});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Profile _p = widget.profile;
  bool _briefing = true;

  @override
  void initState() {
    super.initState();
    Notify.briefingOn().then((v) {
      if (mounted) setState(() => _briefing = v);
    });
  }

  Future<void> _refresh() async {
    final p = await Db.getProfile();
    if (p != null && mounted) setState(() => _p = p);
  }

  Future<void> _editTime(bool wake) async {
    final t = await showTimePicker(context: context, initialTime: parseHm(wake ? _p.wakeTime : _p.sleepTime));
    if (t == null) return;
    await Db.saveProfile({wake ? 'wake_time' : 'sleep_time': hm(t)});
    if (wake && _briefing) await Notify.setBriefing(true, t.hour, t.minute);
    await _refresh();
  }

  Future<void> _editGoals() async {
    final c = TextEditingController(text: _p.goals ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('요즘 목표'),
        content: TextField(controller: c, maxLines: 3, decoration: const InputDecoration(hintText: 'AI가 계획을 짤 때 참고해요')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    if (ok != true) return;
    await Db.saveProfile({'goals': c.text.trim()});
    await _refresh();
  }

  Future<void> _deleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('계정을 삭제할까요?'),
        content: const Text('일정, 습관, 기록, 학습 자료, 대화 내용이 모두 지워지고 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('영구 삭제'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await AuthService.deleteAccount();
    } catch (e) {
      if (mounted) toast(context, '삭제하지 못했어요: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text('${_p.nickname}님${_p.grade != null ? ' · ${_p.grade}' : ''}',
              style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ListTile(leading: const Icon(Icons.wb_sunny_outlined), title: const Text('일어나는 시간'), trailing: Text(_p.wakeTime), onTap: () => _editTime(true)),
        ListTile(leading: const Icon(Icons.bedtime_outlined), title: const Text('자는 시간'), trailing: Text(_p.sleepTime), onTap: () => _editTime(false)),
        ListTile(
          leading: const Icon(Icons.flag_outlined),
          title: const Text('요즘 목표'),
          subtitle: Text((_p.goals ?? '').isEmpty ? '없음' : _p.goals!),
          onTap: _editGoals,
        ),
        const Divider(),
        SwitchListTile(
          secondary: const Icon(Icons.notifications_active_outlined),
          title: const Text('아침 브리핑 알림'),
          subtitle: Text('매일 ${_p.wakeTime}에 오늘 일정을 알려 줘요'),
          value: _briefing,
          onChanged: (v) async {
            setState(() => _briefing = v);
            final w = parseHm(_p.wakeTime);
            await Notify.setBriefing(v, w.hour, w.minute);
          },
        ),
        ListTile(
          leading: const Icon(Icons.sync),
          title: const Text('일정 알림 다시 맞추기'),
          subtitle: const Text('알림이 안 올 때 눌러 보세요'),
          onTap: () async {
            await Notify.requestPermissions();
            await Notify.resyncUpcoming();
            if (context.mounted) toast(context, '앞으로 30일 일정 알림을 다시 맞췄어요');
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('개인정보처리방침'),
          onTap: () => launchUrl(Uri.parse(AppConfig.privacyPolicyUrl)),
        ),
        ListTile(leading: const Icon(Icons.logout), title: const Text('로그아웃'), onTap: AuthService.signOut),
        ListTile(
          leading: const Icon(Icons.person_remove_outlined, color: Colors.red),
          title: const Text('계정 삭제', style: TextStyle(color: Colors.red)),
          onTap: _deleteAccount,
        ),
        const SizedBox(height: 16),
        Center(child: Text('PlanAI 1.0.0', style: t.bodySmall)),
        const SizedBox(height: 24),
      ]),
    );
  }
}
