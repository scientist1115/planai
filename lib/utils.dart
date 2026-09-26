import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';

String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String hm(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay parseHm(String s) {
  final p = s.split(':');
  return TimeOfDay(
    hour: int.tryParse(p[0]) ?? 7,
    minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0,
  );
}

String fmtTime(DateTime d) => DateFormat('HH:mm').format(d);
String fmtRange(PlanEvent e) => e.end == null ? fmtTime(e.start) : '${fmtTime(e.start)}~${fmtTime(e.end!)}';
String fmtDateShort(DateTime d) => DateFormat('M/d(E)', 'ko_KR').format(d);
String fmtDateLong(DateTime d) => DateFormat('M월 d일 EEEE', 'ko_KR').format(d);

String mimeFromName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  if (n.endsWith('.gif')) return 'image/gif';
  if (n.endsWith('.pdf')) return 'application/pdf';
  if (n.endsWith('.txt')) return 'text/plain';
  return 'image/jpeg';
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// 브랜드 색: 잉크 파랑 + 형광펜 노랑 (종이 플래너에 펜으로 쓰고 형광펜 칠하는 느낌)
const kInk = Color(0xFF3D4FD6);
const kHighlighter = Color(0xFFFFD84D);
