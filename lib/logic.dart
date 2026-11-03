import 'db.dart';

/// قواعد النتائج - تُقرأ من الإعدادات (قابلة للضبط من شاشة الإعدادات).
class Rules {
  final double passPercent; // نسبة النجاح في المادة من درجتها الكلية
  final int maxFailedSecondRound; // أقصى عدد مواد للدور الثاني
  final double excellent, veryGood, good, ok; // حدود التقديرات (نسبة)
  final double maxW1, maxE1, maxW2, maxE2; // سقوف الدرجات
  const Rules({
    required this.passPercent, required this.maxFailedSecondRound,
    required this.excellent, required this.veryGood,
    required this.good, required this.ok,
    required this.maxW1, required this.maxE1,
    required this.maxW2, required this.maxE2,
  });

  double get subjectMax => maxW1 + maxE1 + maxW2 + maxE2;

  static Future<Rules> load() async {
    Future<double> n(String k) async =>
        double.tryParse(await Db.setting(k)) ?? double.parse(Db.defaults[k]!);
    return Rules(
      passPercent: await n('min_percent'),
      maxFailedSecondRound: (await n('max_failed_second_round')).toInt(),
      excellent: await n('r_excellent'), veryGood: await n('r_verygood'),
      good: await n('r_good'), ok: await n('r_ok'),
      maxW1: await n('max_t1_work'), maxE1: await n('max_t1_exam'),
      maxW2: await n('max_t2_work'), maxE2: await n('max_t2_exam'),
    );
  }

  String rating(double pct) {
    if (pct >= excellent) return 'ممتاز';
    if (pct >= veryGood) return 'جيد جداً';
    if (pct >= good) return 'جيد';
    if (pct >= ok) return 'مقبول';
    return 'ضعيف';
  }
}

class SubjectScore {
  final String name;
  final double? t1Work, t1Exam, t2Work, t2Exam;
  SubjectScore(this.name, this.t1Work, this.t1Exam, this.t2Work, this.t2Exam);

  bool get hasAny =>
      t1Work != null || t1Exam != null || t2Work != null || t2Exam != null;
  double get total =>
      (t1Work ?? 0) + (t1Exam ?? 0) + (t2Work ?? 0) + (t2Exam ?? 0);
}

class StudentResult {
  final double total, max, percent;
  final String status, rating;
  final List<String> failed;
  StudentResult(this.total, this.max, this.percent, this.status, this.rating,
      this.failed);
}

StudentResult compute(List<SubjectScore> subs, Rules r) {
  final max = subs.length * r.subjectMax;
  if (subs.isEmpty || subs.every((s) => !s.hasAny)) {
    return StudentResult(0, max, 0, 'غائب', '-', []);
  }
  final minPass = r.subjectMax * r.passPercent / 100;
  final failed = <String>[];
  var total = 0.0;
  for (final s in subs) {
    total += s.total;
    if (s.total < minPass) failed.add(s.name);
  }
  final pct = total / max * 100;
  final status = failed.isEmpty
      ? 'ناجح'
      : failed.length <= r.maxFailedSecondRound
          ? 'دور ثانٍ'
          : 'راسب';
  return StudentResult(total, max, pct, status, r.rating(pct), failed);
}

/// يقسم [total] طالباً على لجان لا تتجاوز [capacity] بأحجام متقاربة.
List<int> splitSizes(int total, int capacity) {
  if (total <= 0 || capacity <= 0) return [];
  final n = (total + capacity - 1) ~/ capacity;
  final base = total ~/ n, rem = total % n;
  return [for (var i = 0; i < n; i++) base + (i < rem ? 1 : 0)];
}

/// ترتيب تنافسي: المتساوون يأخذون الترتيب نفسه ثم يقفز الترتيب.
/// [totalsDesc] مجاميع مرتبة تنازلياً.
List<int> competitionRanks(List<double> totalsDesc) {
  final out = <int>[];
  for (var i = 0; i < totalsDesc.length; i++) {
    out.add(i > 0 && totalsDesc[i] == totalsDesc[i - 1] ? out[i - 1] : i + 1);
  }
  return out;
}

/// إعدادات الدرجات الشهرية (أربعة مكونات وتحويل لسقف أصغر).
class MonthlyCfg {
  final double hw, att, oral, written, convertTo;
  final List<String> labels;
  const MonthlyCfg(this.hw, this.att, this.oral, this.written, this.convertTo,
      this.labels);

  double get total => hw + att + oral + written;
  List<double> get maxes => [hw, att, oral, written];
  double convert(double sum) => total == 0 ? 0 : sum / total * convertTo;

  static Future<MonthlyCfg> load() async {
    Future<double> n(String k) async =>
        double.tryParse(await Db.setting(k)) ?? double.parse(Db.defaults[k]!);
    return MonthlyCfg(
      await n('m_hw'), await n('m_att'), await n('m_oral'),
      await n('m_written'), await n('m_convert'),
      [
        await Db.setting('ml_hw'), await Db.setting('ml_att'),
        await Db.setting('ml_oral'), await Db.setting('ml_written'),
      ],
    );
  }
}

/// تنسيق رقم: بدون كسر إن كان صحيحاً.
String nf(num? v) {
  if (v == null) return '';
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);
}
