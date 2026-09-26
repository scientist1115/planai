import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import '../utils.dart';

/// 데이터가 바뀔 때마다 1씩 올라갑니다. 달력·습관 화면이 이걸 듣고 새로고침해요.
final dataVersion = ValueNotifier<int>(0);
void bumpData() => dataVersion.value++;

class Db {
  static SupabaseClient get _c => Supabase.instance.client;
  static String get uid => _c.auth.currentUser!.id;

  // ── 프로필 ──
  static Future<Profile?> getProfile() async {
    final m = await _c.from('profiles').select().eq('id', uid).maybeSingle();
    return m == null ? null : Profile.fromMap(m);
  }

  static Future<void> saveProfile(Map<String, dynamic> data) async {
    await _c.from('profiles').upsert({'id': uid, ...data});
  }

  // ── 일정 ──
  static Future<List<PlanEvent>> eventsBetween(DateTime from, DateTime to) async {
    final rows = await _c
        .from('events')
        .select()
        .gte('start_at', from.toUtc().toIso8601String())
        .lt('start_at', to.toUtc().toIso8601String())
        .order('start_at');
    return rows.map((m) => PlanEvent.fromMap(m)).toList();
  }

  static Future<List<PlanEvent>> eventsOnDay(DateTime d) {
    final s = DateTime(d.year, d.month, d.day);
    return eventsBetween(s, s.add(const Duration(days: 1)));
  }

  static Future<PlanEvent> addEvent(PlanEvent e) async {
    final m = await _c.from('events').insert({...e.toRow(), 'user_id': uid}).select().single();
    bumpData();
    return PlanEvent.fromMap(m);
  }

  static Future<void> updateEvent(PlanEvent e) async {
    await _c.from('events').update(e.toRow()).eq('id', e.id!);
    bumpData();
  }

  static Future<void> deleteEvent(String id) async {
    await _c.from('events').delete().eq('id', id);
    bumpData();
  }

  // ── 습관 ──
  static Future<List<Habit>> habits() async {
    final rows = await _c.from('habits').select().order('created_at');
    return rows.map((m) => Habit.fromMap(m)).toList();
  }

  static Future<Habit> addHabit(String name, String emoji) async {
    final m = await _c.from('habits').insert({'user_id': uid, 'name': name, 'emoji': emoji}).select().single();
    bumpData();
    return Habit.fromMap(m);
  }

  static Future<void> deleteHabit(String id) async {
    await _c.from('habits').delete().eq('id', id);
    bumpData();
  }

  static Future<Set<String>> habitDoneIds(DateTime day) async {
    final rows = await _c.from('habit_logs').select('habit_id').eq('day', dayKey(day));
    return rows.map((r) => r['habit_id'] as String).toSet();
  }

  static Future<void> setHabit(String habitId, DateTime day, bool done) async {
    if (done) {
      await _c.from('habit_logs').upsert(
        {'habit_id': habitId, 'user_id': uid, 'day': dayKey(day)},
        onConflict: 'habit_id,day',
      );
    } else {
      await _c.from('habit_logs').delete().eq('habit_id', habitId).eq('day', dayKey(day));
    }
    bumpData();
  }

  /// 날짜별 습관 달성 개수 (달력의 ⭐ 표시용)
  static Future<Map<String, int>> habitCountsByDay(DateTime from, DateTime to) async {
    final rows = await _c.from('habit_logs').select('day').gte('day', dayKey(from)).lte('day', dayKey(to));
    final out = <String, int>{};
    for (final r in rows) {
      final k = r['day'] as String;
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  /// 습관별 달성 일수 (습관 화면용)
  static Future<Map<String, int>> habitCountsByHabit(DateTime from, DateTime to) async {
    final rows = await _c.from('habit_logs').select('habit_id').gte('day', dayKey(from)).lte('day', dayKey(to));
    final out = <String, int>{};
    for (final r in rows) {
      final k = r['habit_id'] as String;
      out[k] = (out[k] ?? 0) + 1;
    }
    return out;
  }

  // ── 하루 기록(메모·감사일기·기분) ──
  static Future<DayJournal> journal(DateTime day) async {
    final m = await _c.from('day_journals').select().eq('day', dayKey(day)).maybeSingle();
    return m == null ? DayJournal(day: dayKey(day)) : DayJournal.fromMap(m);
  }

  static Future<void> saveJournal(DayJournal j) async {
    await _c.from('day_journals').upsert({...j.toRow(), 'user_id': uid}, onConflict: 'user_id,day');
    bumpData();
  }

  // ── 학습 자료 ──
  static Future<List<StudySet>> studySets(String eventId) async {
    final rows = await _c.from('study_sets').select().eq('event_id', eventId).order('created_at', ascending: false);
    return rows.map((m) => StudySet.fromMap(m)).toList();
  }

  static Future<void> deleteStudySet(String id) async {
    await _c.from('study_sets').delete().eq('id', id);
  }

  // ── AI 대화 기록 ──
  static Future<List<Map<String, dynamic>>> chatHistory({int limit = 40}) async {
    final rows = await _c.from('chat_messages').select().order('created_at', ascending: false).limit(limit);
    return rows.reversed.toList();
  }

  static Future<void> clearChat() async {
    await _c.from('chat_messages').delete().eq('user_id', uid);
  }

  // ── AI 응답 신고 (구글 플레이 AI 콘텐츠 정책 대응) ──
  static Future<void> report(String source, String content, String reason) async {
    await _c.from('ai_reports').insert({'user_id': uid, 'source': source, 'content': content, 'reason': reason});
  }
}
