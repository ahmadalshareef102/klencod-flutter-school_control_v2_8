import 'db.dart';
import 'logic.dart';

class RankedResult {
  final Map<String, Object?> student;
  final StudentResult result;
  final int? rank; // null للغائب
  RankedResult(this.student, this.result, this.rank);
}

/// نتائج صف كامل مرتبة بالمجموع تنازلياً (الغائبون في النهاية).
Future<List<RankedResult>> classResults(int classId, {String? section}) async {
  final d = await Db.get();
  final rules = await Rules.load();
  final subjects =
      await d.query('subjects', where: 'class_id=?', whereArgs: [classId]);
  final students = await d.query('students',
      where: section == null ? 'class_id=?' : 'class_id=? AND section=?',
      whereArgs: section == null ? [classId] : [classId, section],
      orderBy: 'seat_no, id');
  final all = <(Map<String, Object?>, StudentResult)>[];
  for (final s in students) {
    final scores = <SubjectScore>[];
    for (final sub in subjects) {
      final g = await d.query('grades',
          where: 'student_id=? AND subject_id=?',
          whereArgs: [s['id'], sub['id']]);
      final m = g.isEmpty ? <String, Object?>{} : g.first;
      double? n(String k) => (m[k] as num?)?.toDouble();
      scores.add(SubjectScore(sub['name'] as String, n('t1_work'),
          n('t1_exam'), n('t2_work'), n('t2_exam')));
    }
    all.add((s, compute(scores, rules)));
  }
  final present = all.where((e) => e.$2.status != 'غائب').toList()
    ..sort((a, b) => b.$2.total.compareTo(a.$2.total));
  final absent = all.where((e) => e.$2.status == 'غائب').toList();
  final ranks = competitionRanks(present.map((e) => e.$2.total).toList());
  return [
    for (var i = 0; i < present.length; i++)
      RankedResult(present[i].$1, present[i].$2, ranks[i]),
    for (final a in absent) RankedResult(a.$1, a.$2, null),
  ];
}

class TranscriptRow {
  final String subject;
  final double? t1, t2;
  TranscriptRow(this.subject, this.t1, this.t2);
  double get total => (t1 ?? 0) + (t2 ?? 0);
}

/// كشف درجات طالب: مجموع كل فصل لكل مادة.
Future<List<TranscriptRow>> transcript(int sid, int classId) async {
  final d = await Db.get();
  final out = <TranscriptRow>[];
  for (final sub in await Db.subjectsOf(classId)) {
    final g = await d.query('grades',
        where: 'student_id=? AND subject_id=?', whereArgs: [sid, sub['id']]);
    double? t1, t2;
    if (g.isNotEmpty) {
      final m = g.first;
      double? n(String k) => (m[k] as num?)?.toDouble();
      if (n('t1_work') != null || n('t1_exam') != null) {
        t1 = (n('t1_work') ?? 0) + (n('t1_exam') ?? 0);
      }
      if (n('t2_work') != null || n('t2_exam') != null) {
        t2 = (n('t2_work') ?? 0) + (n('t2_exam') ?? 0);
      }
    }
    out.add(TranscriptRow(sub['name'] as String, t1, t2));
  }
  return out;
}
