import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../services/auth.dart';
import '../utils.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) toast(context, '로그인하지 못했어요: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _emailSheet() {
    final email = TextEditingController();
    final pw = TextEditingController();
    var signUp = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(signUp ? '이메일로 가입하기' : '이메일로 로그인', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pw,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호 (8자 이상)'),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _run(() async {
                    if (signUp) {
                      final needsConfirm = await AuthService.signUpEmail(email.text.trim(), pw.text);
                      if (needsConfirm && mounted) {
                        toast(context, '확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.');
                      }
                    } else {
                      await AuthService.signInEmail(email.text.trim(), pw.text);
                    }
                  });
                },
                child: Text(signUp ? '가입하기' : '로그인'),
              ),
              TextButton(
                onPressed: () => setS(() => signUp = !signUp),
                child: Text(signUp ? '이미 계정이 있어요' : '처음이에요 (회원가입)'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              // 형광펜으로 칠한 듯한 로고
              Center(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    Container(width: 150, height: 18, color: kHighlighter),
                    Text('PlanAI', style: t.displaySmall?.copyWith(fontWeight: FontWeight.w900, color: kInk)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('말만 하면 계획이 완성되는 플래너', textAlign: TextAlign.center, style: t.titleMedium),
              const SizedBox(height: 6),
              Text('"내일 4시 영어학원" 이렇게 말하면 끝이에요', textAlign: TextAlign.center, style: t.bodyMedium),
              const Spacer(flex: 3),
              _LoginButton(
                label: '카카오로 시작하기',
                bg: const Color(0xFFFEE500),
                fg: Colors.black87,
                onTap: () => _run(AuthService.kakao),
              ),
              const SizedBox(height: 10),
              _LoginButton(
                label: '네이버로 시작하기',
                bg: const Color(0xFF03C75A),
                fg: Colors.white,
                onTap: () => _run(AuthService.naver),
              ),
              if (Platform.isIOS) ...[
                const SizedBox(height: 10),
                _LoginButton(
                  label: 'Apple로 계속하기',
                  bg: Colors.black,
                  fg: Colors.white,
                  icon: Icons.apple,
                  onTap: () => _run(AuthService.apple),
                ),
              ],
              const SizedBox(height: 6),
              TextButton(onPressed: _busy ? null : _emailSheet, child: const Text('이메일로 가입 / 로그인')),
              if (_busy) const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text('시작하면 이용약관과 개인정보처리방침에 동의하게 됩니다.', textAlign: TextAlign.center, style: t.bodySmall),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;
  final VoidCallback onTap;

  const _LoginButton({required this.label, required this.bg, required this.fg, required this.onTap, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        icon: icon == null ? const SizedBox.shrink() : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }
}
