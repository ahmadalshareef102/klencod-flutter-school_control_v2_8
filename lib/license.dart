import 'dart:convert';
import 'dart:math';
import 'package:android_id/android_id.dart';
import 'package:crypto/crypto.dart';
import 'app_info.dart';
import 'db.dart';

/// يُرمى عند محاولة تجاوز حد الطلاب المسموح به في النسخة الحالية.
class LicenseLimitException implements Exception {
  final int limit;
  LicenseLimitException(this.limit);
  @override
  String toString() => 'بلغت الحد الأقصى للطلاب ($limit)';
}

class LicenseState {
  final bool activated; // كود صالح ومرتبط بهذا الجهاز
  final bool expired; // كود صالح لكنه منتهي المدة
  final int limit; // -1 = غير محدود
  final DateTime? expiry;
  const LicenseState(this.activated, this.expired, this.limit, this.expiry);

  bool get unlimited => limit < 0;
  String get title => activated
      ? (unlimited ? 'نسخة مفعّلة (غير محدودة)' : 'نسخة مفعّلة (حتى $limit طالب)')
      : expired
          ? 'انتهت مدة التفعيل'
          : 'نسخة مجانية (حتى ${License.freeLimit} طالب)';
}

/// ترخيص بدون إنترنت: كود تفعيل مرتبط برقم الجهاز، يولّده المطور.
class License {
  /// الحد المجاني قبل التفعيل.
  static const freeLimit = 100;

  // السر مخفي بقناع حتى لا يظهر نصاً صريحاً في الملف.
  static const List<int> _a = [252, 232, 55, 0, 125, 115, 238, 167, 129, 153, 203, 144, 134, 247, 213, 102, 162, 141, 208, 162, 46, 126, 223, 166, 242, 26, 230, 35, 151, 228, 187, 248];
  static const List<int> _b = [117, 133, 53, 78, 175, 123, 40, 184, 80, 10, 56, 181, 30, 231, 88, 191, 96, 247, 197, 191, 67, 105, 184, 217, 142, 242, 107, 253, 71, 190, 37, 101];
  static List<int> get _secret =>
      [for (var i = 0; i < _a.length; i++) _a[i] ^ _b[i]];

  /// يحسب التوقيع (16 خانة) لرقم جهاز وخطة وانتهاء.
  static String sign(String deviceId, String limit, String expiry) {
    final mac = Hmac(sha256, _secret)
        .convert(utf8.encode('$deviceId|$limit|$expiry'));
    return mac.bytes
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  /// رقم الجهاز (ANDROID_ID) أو رقم عشوائي محفوظ إن تعذّر.
  static Future<String> deviceId() async {
    String? id;
    try {
      id = await const AndroidId().getId();
    } catch (_) {}
    if (id == null || id.isEmpty) {
      var f = await Db.setting('device_fallback');
      if (f.isEmpty) {
        final r = Random.secure();
        f = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
        await Db.setSetting('device_fallback', f);
      }
      id = f;
    }
    return id.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  /// يعرض الرقم مقسماً: ABCD-EFGH-...
  static String pretty(String id) {
    final parts = <String>[];
    for (var i = 0; i < id.length; i += 4) {
      parts.add(id.substring(i, i + 4 > id.length ? id.length : i + 4));
    }
    return parts.join('-');
  }

  static ({int limit, DateTime? expiry})? _verify(String deviceId, String raw) {
    final code = raw.toUpperCase().replaceAll(RegExp(r'\s'), '');
    final p = code.split('-');
    if (p.length != 6) return null;
    final lim = p[0], exp = p[1];
    if (lim != 'U' && int.tryParse(lim) == null) return null;
    if (int.tryParse(exp) == null) return null;
    final given = p.sublist(2).join();
    final want = sign(deviceId, lim, exp);
    if (given.length != want.length) return null;
    var diff = 0;
    for (var i = 0; i < want.length; i++) {
      diff |= given.codeUnitAt(i) ^ want.codeUnitAt(i);
    }
    if (diff != 0) return null;
    DateTime? expiry;
    if (exp != '0') {
      if (exp.length != 8) return null;
      expiry = DateTime.tryParse('${exp.substring(0, 4)}-${exp.substring(4, 6)}-${exp.substring(6, 8)}');
      if (expiry == null) return null;
    }
    return (limit: lim == 'U' ? -1 : int.parse(lim), expiry: expiry);
  }

  static Future<LicenseState> state() async {
    final code = await Db.setting('license_code');
    const free = LicenseState(false, false, freeLimit, null);
    if (code.isEmpty) return free;
    final v = _verify(await deviceId(), code);
    if (v == null) return free;
    if (v.expiry != null && DateTime.now().isAfter(v.expiry!.add(const Duration(days: 1)))) {
      return LicenseState(false, true, freeLimit, v.expiry);
    }
    return LicenseState(true, false, v.limit, v.expiry);
  }

  /// يتحقق من الكود ويحفظه؛ يعيد true عند النجاح.
  static Future<bool> activate(String code) async {
    final v = _verify(await deviceId(), code);
    if (v == null) return false;
    await Db.setSetting('license_code', code.toUpperCase().replaceAll(RegExp(r'\s'), ''));
    return true;
  }

  static Future<void> deactivate() => Db.setSetting('license_code', '');

  /// يرمي [LicenseLimitException] إن كانت إضافة [n] طلاب تتجاوز الحد.
  static Future<void> ensureCanAdd([int n = 1]) async {
    final s = await state();
    if (s.unlimited) return;
    final count = await Db.count('SELECT COUNT(*) FROM students');
    if (count + n > s.limit) throw LicenseLimitException(s.limit);
  }

  /// نص طلب التفعيل المرسل للمطور.
  static Future<String> requestMessage() async {
    final id = pretty(await deviceId());
    final count = await Db.count('SELECT COUNT(*) FROM students');
    final s = await state();
    final school = await Db.setting('school');
    final teacher = await Db.setting('teacher');
    final now = DateTime.now();
    return [
      'طلب تفعيل تطبيق ${AppInfo.appName}',
      'الإصدار: ${AppInfo.version}',
      'رقم الجهاز: $id',
      if (school.isNotEmpty) 'المدرسة: $school',
      if (teacher.isNotEmpty) 'الاسم: $teacher',
      'عدد الطلاب الحالي: $count من ${s.unlimited ? 'غير محدود' : s.limit}',
      'الحالة: ${s.title}',
      'التاريخ: ${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    ].join('\n');
  }
}
