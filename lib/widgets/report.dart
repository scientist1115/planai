import 'package:flutter/material.dart';
import '../services/db.dart';
import '../utils.dart';

/// AI가 만든 내용 신고 (구글 플레이 'AI 생성 콘텐츠' 정책: 앱 안에서 신고할 수 있어야 함)
Future<void> showReportDialog(BuildContext context, {required String source, required String content}) async {
  const reasons = ['틀린 내용이에요', '부적절하거나 불쾌한 내용이에요', '개인정보가 들어 있어요', '기타'];
  var selected = reasons.first;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setS) => AlertDialog(
        title: const Text('AI 응답 신고하기'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in reasons)
              RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                value: r,
                groupValue: selected,
                title: Text(r),
                onChanged: (v) => setS(() => selected = v!),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('신고하기')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  try {
    await Db.report(source, content, selected);
    if (context.mounted) toast(context, '신고했어요. 검토해서 개선할게요.');
  } catch (e) {
    if (context.mounted) toast(context, '신고하지 못했어요: $e');
  }
}
