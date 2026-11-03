class HijriDate {
  final int y, m, d;
  const HijriDate(this.y, this.m, this.d);
}

/// تحويل ميلادي إلى هجري بالحساب الجدولي (قد يختلف يوماً عن أم القرى)؛
/// [offset] إزاحة يدوية بالأيام.
HijriDate toHijri(DateTime g, {int offset = 0}) {
  final date = g.add(Duration(days: offset));
  final y = date.year, m = date.month, d = date.day;
  final a = (14 - m) ~/ 12;
  final yy = y + 4800 - a;
  final mm = m + 12 * a - 3;
  final jd = d +
      ((153 * mm + 2) ~/ 5) +
      365 * yy +
      (yy ~/ 4) -
      (yy ~/ 100) +
      (yy ~/ 400) -
      32045;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l -
      ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) +
      29;
  final mon = (24 * l) ~/ 709;
  final day = l - ((709 * mon) ~/ 24);
  final year = 30 * n + j - 30;
  return HijriDate(year, mon, day);
}

const hijriMonths = [
  'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى',
  'جمادى الآخرة', 'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
];
const gregMonths = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];
const weekDays = [
  'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
];

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d, {required bool hijri, int offset = 0}) {
  final day = weekDays[d.weekday - 1];
  if (hijri) {
    final h = toHijri(d, offset: offset);
    return '$day ${h.y}/${two(h.m)}/${two(h.d)} هـ';
  }
  return '$day ${d.year}/${two(d.month)}/${two(d.day)} م';
}

String isoDate(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

String monthName(int m, bool hijri) =>
    (hijri ? hijriMonths : gregMonths)[(m - 1) % 12];
