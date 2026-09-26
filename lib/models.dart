import 'package:flutter/material.dart';

class Profile {
  final String id;
  final String nickname;
  final int? birthYear;
  final String? grade;
  final String wakeTime;
  final String sleepTime;
  final String? goals;
  final bool onboarded;

  Profile({
    required this.id,
    required this.nickname,
    this.birthYear,
    this.grade,
    this.wakeTime = '07:00',
    this.sleepTime = '23:00',
    this.goals,
    this.onboarded = false,
  });

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        nickname: (m['nickname'] ?? '') as String,
        birthYear: m['birth_year'] as int?,
        grade: m['grade'] as String?,
        wakeTime: (m['wake_time'] ?? '07:00') as String,
        sleepTime: (m['sleep_time'] ?? '23:00') as String,
        goals: m['goals'] as String?,
        onboarded: (m['onboarded'] ?? false) as bool,
      );
}

const kCategories = ['공부', '학교/일', '운동', '약속', '생활', '기타'];
const kSubjects = ['영어', '한국사', '수학', '국어', '과학', '사회', '기타'];

/// 아이젠하워 매트릭스(중요/급함) 4칸
const kQuadrantLabels = {1: '중요·급함', 2: '중요', 3: '급함', 4: '나중에'};

Color quadrantColor(int q) {
  switch (q) {
    case 1:
      return const Color(0xFFE5484D);
    case 2:
      return const Color(0xFF3D4FD6);
    case 3:
      return const Color(0xFFF08C00);
    default:
      return const Color(0xFF8B8D98);
  }
}

class PlanEvent {
  final String? id;
  String title;
  DateTime start;
  DateTime? end;
  String category;
  String? subject;
  int quadrant;
  bool done;
  String? notes;

  PlanEvent({
    this.id,
    required this.title,
    required this.start,
    this.end,
    this.category = '기타',
    this.subject,
    this.quadrant = 4,
    this.done = false,
    this.notes,
  });

  bool get isStudy => category == '공부';

  PlanEvent copy() => PlanEvent(
        id: id,
        title: title,
        start: start,
        end: end,
        category: category,
        subject: subject,
        quadrant: quadrant,
        done: done,
        notes: notes,
      );

  factory PlanEvent.fromMap(Map<String, dynamic> m) => PlanEvent(
        id: m['id'] as String,
        title: m['title'] as String,
        start: DateTime.parse(m['start_at'] as String).toLocal(),
        end: m['end_at'] == null ? null : DateTime.parse(m['end_at'] as String).toLocal(),
        category: (m['category'] ?? '기타') as String,
        subject: m['subject'] as String?,
        quadrant: (m['quadrant'] ?? 4) as int,
        done: (m['done'] ?? false) as bool,
        notes: m['notes'] as String?,
      );

  Map<String, dynamic> toRow() => {
        'title': title,
        'start_at': start.toUtc().toIso8601String(),
        'end_at': end?.toUtc().toIso8601String(),
        'category': category,
        'subject': isStudy ? subject : null,
        'quadrant': quadrant,
        'done': done,
        'notes': notes,
      };

  /// AI가 제안한 JSON({title, date, start, end, category, subject, quadrant}) → PlanEvent
  static PlanEvent? fromProposal(Map<String, dynamic> p) {
    try {
      final date = DateTime.parse(p['date'] as String);
      DateTime at(String hm) {
        final parts = hm.split(':');
        return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
      }

      final start = at((p['start'] as String?) ?? '09:00');
      final endStr = p['end'] as String?;
      DateTime? end = (endStr == null || endStr.isEmpty) ? null : at(endStr);
      if (end != null && end.isBefore(start)) end = end.add(const Duration(days: 1));
      final cat = kCategories.contains(p['category']) ? p['category'] as String : '기타';
      final q = ((p['quadrant'] as num?)?.toInt() ?? 4).clamp(1, 4).toInt();
      return PlanEvent(
        title: p['title'] as String,
        start: start,
        end: end,
        category: cat,
        subject: p['subject'] as String?,
        quadrant: q,
      );
    } catch (_) {
      return null;
    }
  }
}

class Habit {
  final String id;
  final String name;
  final String emoji;
  Habit({required this.id, required this.name, required this.emoji});
  factory Habit.fromMap(Map<String, dynamic> m) =>
      Habit(id: m['id'] as String, name: m['name'] as String, emoji: (m['emoji'] ?? '✅') as String);
}

class DayJournal {
  final String day; // yyyy-MM-dd
  String? memo;
  String? gratitude;
  int? mood; // 1~5
  DayJournal({required this.day, this.memo, this.gratitude, this.mood});

  factory DayJournal.fromMap(Map<String, dynamic> m) => DayJournal(
        day: m['day'] as String,
        memo: m['memo'] as String?,
        gratitude: m['gratitude'] as String?,
        mood: m['mood'] as int?,
      );

  Map<String, dynamic> toRow() => {'day': day, 'memo': memo, 'gratitude': gratitude, 'mood': mood};
}

const kStudyKinds = {'vocab': '영단어장', 'history': '한국사 암기', 'general': '요약·퀴즈'};
const kStudyEmoji = {'vocab': '🔤', 'history': '📜', 'general': '📝'};

class StudySet {
  final String id;
  final String? eventId;
  final String subject;
  final String kind; // vocab | history | general
  final Map<String, dynamic> content;
  final DateTime createdAt;

  StudySet({required this.id, this.eventId, required this.subject, required this.kind, required this.content, required this.createdAt});

  String get title => (content['title'] as String?) ?? kStudyKinds[kind] ?? '학습 자료';

  factory StudySet.fromMap(Map<String, dynamic> m) => StudySet(
        id: m['id'] as String,
        eventId: m['event_id'] as String?,
        subject: (m['subject'] ?? '') as String,
        kind: m['kind'] as String,
        content: Map<String, dynamic>.from(m['content'] as Map),
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
