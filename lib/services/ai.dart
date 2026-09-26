import 'dart:convert';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models.dart';

class Attachment {
  final Uint8List bytes;
  final String mime;
  final String name;
  Attachment(this.bytes, this.mime, this.name);
}

class ChatResult {
  final String reply;
  final List<PlanEvent> events;
  final List<String> habits;
  final Map<String, dynamic>? journal;
  ChatResult(this.reply, this.events, this.habits, this.journal);
}

/// AI 호출은 전부 Supabase Edge Function을 거칩니다. (API 키를 앱에 넣지 않기 위해)
class Ai {
  static FunctionsClient get _f => Supabase.instance.client.functions;

  static String _now() => DateFormat('yyyy-MM-dd HH:mm (EEEE)', 'ko_KR').format(DateTime.now());

  static String _tzName() {
    try {
      return tz.local.name;
    } catch (_) {
      return 'Asia/Seoul';
    }
  }

  static Map<String, dynamic> _asMap(dynamic d) =>
      d is String ? jsonDecode(d) as Map<String, dynamic> : Map<String, dynamic>.from(d as Map);

  static Future<ChatResult> chat(String text, {Attachment? image}) async {
    final res = await _f.invoke('ai-chat', body: {
      'message': text,
      'now': _now(),
      'tz': _tzName(),
      if (image != null) 'image': base64Encode(image.bytes),
      if (image != null) 'image_mime': image.mime,
    });
    final d = _asMap(res.data);
    final events = ((d['events'] as List?) ?? [])
        .map((e) => PlanEvent.fromProposal(Map<String, dynamic>.from(e as Map)))
        .whereType<PlanEvent>()
        .toList();
    final habits = ((d['habits'] as List?) ?? []).map((e) => e.toString()).toList();
    final journal = d['journal'] == null ? null : Map<String, dynamic>.from(d['journal'] as Map);
    return ChatResult((d['reply'] ?? '') as String, events, habits, journal);
  }

  static Future<StudySet> makeStudy({
    required PlanEvent event,
    required String kind,
    String? text,
    Attachment? file,
  }) async {
    final res = await _f.invoke('ai-study', body: {
      'event_id': event.id,
      'event_title': event.title,
      'subject': event.subject ?? '',
      'kind': kind,
      'text': text ?? '',
      if (file != null) 'file': base64Encode(file.bytes),
      if (file != null) 'file_mime': file.mime,
    });
    return StudySet.fromMap(_asMap(res.data));
  }
}
