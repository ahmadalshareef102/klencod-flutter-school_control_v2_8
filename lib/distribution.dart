import 'dart:math';

/// طالب مشارك في التوزيع.
class DistStudent {
  final int id, classId;
  final String name, gender; // gender: ذكر / أنثى
  final String key; // مفتاح الترتيب الأبجدي
  final int? seat;
  DistStudent(this.id, this.name, this.classId, this.gender, {this.seat})
      : key = alphaKey(name);
  String get code => gender == 'أنثى' ? 'F' : 'M';
}

/// تعريف لجنة: نوعها (M ذكور، F إناث، X مختلط) وحصة كل صف.
class CommitteeSpec {
  final int no;
  final String gender;
  final Map<int, int> quotas;
  CommitteeSpec(this.no, this.gender, [Map<int, int>? q]) : quotas = q ?? {};
  int get total => quotas.values.fold(0, (a, b) => a + b);
  String get label => gender == 'M' ? 'ذكور' : gender == 'F' ? 'إناث' : 'مختلط';
}

class PlanResult {
  final Map<int, List<int>> assign;
  final List<String> errors, warnings;
  final List<int> unplaced;
  PlanResult(this.assign, this.errors, this.warnings, this.unplaced);
}

/// مفتاح الترتيب: يوحّد الهمزات والتاء المربوطة والألف المقصورة ويحذف التشكيل.
String alphaKey(String s) {
  var t = s.trim();
  t = t.replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '');
  t = t
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه');
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

int compareAlpha(DistStudent a, DistStudent b) {
  final c = a.key.compareTo(b.key);
  return c != 0 ? c : a.id.compareTo(b.id);
}

/// يولّد لجاناً وحصصاً متوازنة تلقائياً.
/// [males] و[females] و[mixed] عدد اللجان (0 = يُحسب من السعة).
List<CommitteeSpec> autoSpecs({
  required List<DistStudent> students,
  required Set<int> classes,
  required bool separate,
  required int capacity,
  int males = 0,
  int females = 0,
  int mixed = 0,
}) {
  final part = students.where((s) => classes.contains(s.classId)).toList();
  final classIds = classes.toList()..sort();
  final cap = capacity < 1 ? 1 : capacity;
  final specs = <CommitteeSpec>[];
  var no = 0;

  void build(String g, int count) {
    final pool = part.where((s) => g == 'X' || s.code == g).toList();
    if (pool.isEmpty) return;
    final k = count > 0 ? count : max(1, (pool.length / cap).ceil());
    final list = [for (var i = 0; i < k; i++) CommitteeSpec(++no, g)];
    var rot = 0;
    for (final c in classIds) {
      final n = pool.where((s) => s.classId == c).length;
      if (n == 0) continue;
      final base = n ~/ k, rem = n % k;
      for (var i = 0; i < k; i++) {
        final extra = ((i - rot) % k) < rem ? 1 : 0;
        list[i].quotas[c] = base + extra;
      }
      rot = (rot + rem) % k;
    }
    specs.addAll(list);
  }

  if (separate) {
    build('M', males);
    build('F', females);
  } else {
    build('X', mixed);
  }
  return specs;
}

/// ينفّذ التوزيع: لكل صف (ولكل جنس عند الفصل) تُرتَّب الأسماء أبجدياً
/// وتُسلَّم للجان بالتتابع بحسب الحصص.
PlanResult runDistribution({
  required List<DistStudent> students,
  required List<CommitteeSpec> specs,
  required bool separate,
  required Map<int, String> classNames,
}) {
  final assign = {for (final s in specs) s.no: <int>[]};
  final errors = <String>[], warnings = <String>[];
  final unplaced = <int>[];
  final classIds = {for (final s in students) s.classId}.toList()..sort();
  final groups = separate ? ['M', 'F'] : ['X'];
  for (final c in classIds) {
    for (final g in groups) {
      final pool = students
          .where((s) => s.classId == c && (g == 'X' || s.code == g))
          .toList()
        ..sort(compareAlpha);
      if (pool.isEmpty) continue;
      final comms = specs.where((sp) => sp.gender == g).toList()
        ..sort((a, b) => a.no.compareTo(b.no));
      var idx = 0;
      for (final sp in comms) {
        final q = sp.quotas[c] ?? 0;
        final take = min(q, pool.length - idx);
        for (var k = 0; k < take; k++) {
          assign[sp.no]!.add(pool[idx++].id);
        }
        if (take < q) {
          warnings.add(
              'لجنة ${sp.no}: المطلوب $q من ${classNames[c] ?? c} لكن المتاح $take فقط');
        }
      }
      if (idx < pool.length) {
        final left = pool.length - idx;
        unplaced.addAll(pool.skip(idx).map((s) => s.id));
        final who = g == 'M' ? 'ذكور' : g == 'F' ? 'إناث' : 'طلاب';
        errors.add('$left من $who ${classNames[c] ?? c} بلا لجنة: زد الحصص أو أضف لجنة');
      }
    }
  }
  return PlanResult(assign, errors, warnings, unplaced);
}

/// يراجع توزيعاً (حتى بعد التعديل اليدوي): إدراج الجميع، عدم التكرار، السعة.
List<String> checkPlan({
  required Map<int, List<int>> assign,
  required List<DistStudent> students,
  required Set<int> classes,
  required int capacity,
  required bool separate,
  required Map<int, String> committeeGender,
}) {
  final issues = <String>[];
  final byId = {for (final s in students) s.id: s};
  final seen = <int>{};
  for (final e in assign.entries) {
    for (final id in e.value) {
      if (!seen.add(id)) {
        issues.add('الطالب ${byId[id]?.name ?? id} مكرر في أكثر من لجنة');
      }
    }
    if (e.value.length > capacity) {
      issues.add('لجنة ${e.key} تجاوزت السعة (${e.value.length} من $capacity)');
    }
    if (separate) {
      final g = committeeGender[e.key];
      for (final id in e.value) {
        final s = byId[id];
        if (s != null && g != null && g != 'X' && s.code != g) {
          issues.add('لجنة ${e.key}: ${s.name} ليس من جنس اللجنة');
        }
      }
    }
  }
  final expected = students.where((s) => classes.contains(s.classId)).map((s) => s.id).toSet();
  final missing = expected.difference(seen);
  if (missing.isNotEmpty) issues.add('${missing.length} طالب لم يُدرجوا في أي لجنة');
  return issues;
}
