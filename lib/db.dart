import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'distribution.dart' show alphaKey;
import 'license.dart';
import 'logic.dart';

typedef DbRow = Map<String, Object?>;

class Db {
  static Database? _db;

  static const basicSubjects = [
    'القرآن الكريم', 'التربية الإسلامية', 'اللغة العربية',
    'اللغة الإنجليزية', 'الرياضيات', 'العلوم', 'الاجتماعيات',
    'السلوك والمواظبة',
  ];
  static const secSubjects = [
    'القرآن الكريم', 'التربية الإسلامية', 'اللغة العربية',
    'اللغة الإنجليزية', 'الرياضيات', 'الفيزياء', 'الكيمياء', 'الأحياء',
    'السلوك والمواظبة',
  ];
  static const classNames = [
    'الأول أساسي', 'الثاني أساسي', 'الثالث أساسي', 'الرابع أساسي',
    'الخامس أساسي', 'السادس أساسي', 'السابع أساسي', 'الثامن أساسي',
    'التاسع أساسي', 'الأول الثانوي', 'الثاني الثانوي علمي',
    'الثالث الثانوي علمي',
  ];

  /// القيم الافتراضية لجميع الإعدادات.
  static const defaults = {
    'school': '', 'teacher': '', 'year': '1448هـ',
    'theme': 'light', 'font': 'cairo', 'keypad': '1',
    'accent': '4292552567', 'bg_dark': '0', 'bg_light': '1', 'radius': '28',
    'card_style': '0', 'input_outlined': '0', 'compact': '0',
    'font_scale': '1.0', 'font_title': 'same',
    'seat_order': 'alpha', 'cert_office': '', 'cert_admin': '', 'cert_control_head': '',
    'cert_principal': '', 'cert_vice': '', 'cert_bg': '1', 'cert_frame': '1',
    'cert_emblem': '', 'cert_logo': '', 'cert_stamp': '',
    'sem1_from': '1', 'sem1_to': '3', 'sem2_from': '4', 'sem2_to': '6', 'calendar': 'hijri', 'hijri_offset': '0',
    'min_percent': '50', 'max_failed_second_round': '2',
    'max_t1_work': '20', 'max_t1_exam': '30',
    'max_t2_work': '20', 'max_t2_exam': '30',
    'committee_capacity': '25', 'separate_gender': '1',
    'r_excellent': '85', 'r_verygood': '75', 'r_good': '65', 'r_ok': '50',
    'm_hw': '20', 'm_att': '20', 'm_oral': '20', 'm_written': '40',
    'm_convert': '20',
    'ml_hw': 'الواجبات', 'ml_att': 'المواظبة', 'ml_oral': 'الشفهي',
    'ml_written': 'التحريري',
  };

  static const _tables = [
    'settings', 'classes', 'subjects', 'students', 'grades', 'monthly',
    'attendance',
  ];

  static Future<Database> get() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), 'control.db');
    _db = await openDatabase(path,
        version: 4, onCreate: _create, onUpgrade: _upgrade);
    return _db!;
  }

  static Future<void> _upgrade(Database d, int oldV, int newV) async {
    if (oldV < 2) {
      await d.execute('ALTER TABLE students ADD COLUMN committee_no INTEGER');
    }
    if (oldV < 3) {
      for (final c in [
        "section TEXT DEFAULT 'أ'", 'phone TEXT', 'guardian TEXT',
        'birth TEXT', 'notes TEXT', 'reg_no INTEGER', 'reg_date TEXT',
      ]) {
        await d.execute('ALTER TABLE students ADD COLUMN $c');
      }
      await d.execute('UPDATE students SET reg_no = 1000 + id');
      await _createV3Tables(d);
    }
    if (oldV < 4) {
      await d.execute('ALTER TABLE students ADD COLUMN address TEXT');
      await d.execute('ALTER TABLE students ADD COLUMN photo TEXT');
    }
  }

  static Future<void> _createV3Tables(Database d) async {
    await d.execute('''CREATE TABLE IF NOT EXISTS monthly(
      student_id INTEGER, subject_id INTEGER, month INTEGER,
      hw REAL, att REAL, oral REAL, written REAL,
      PRIMARY KEY(student_id, subject_id, month))''');
    await d.execute('''CREATE TABLE IF NOT EXISTS attendance(
      student_id INTEGER, date TEXT, status TEXT,
      PRIMARY KEY(student_id, date))''');
  }

  static Future<void> _create(Database d, int v) async {
    await d.execute('CREATE TABLE settings(k TEXT PRIMARY KEY, v TEXT)');
    await d.execute(
        'CREATE TABLE classes(id INTEGER PRIMARY KEY, name TEXT, seat_start INTEGER)');
    await d.execute(
        'CREATE TABLE subjects(id INTEGER PRIMARY KEY AUTOINCREMENT, class_id INTEGER, name TEXT)');
    await d.execute('''CREATE TABLE students(
      id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, gender TEXT,
      class_id INTEGER, seat_no INTEGER, committee_no INTEGER,
      status TEXT DEFAULT 'مستجد', section TEXT DEFAULT 'أ', phone TEXT,
      guardian TEXT, birth TEXT, notes TEXT, reg_no INTEGER, reg_date TEXT,
      address TEXT, photo TEXT)''');
    await d.execute('''CREATE TABLE grades(
      student_id INTEGER, subject_id INTEGER,
      t1_work REAL, t1_exam REAL, t2_work REAL, t2_exam REAL,
      PRIMARY KEY(student_id, subject_id))''');
    await _createV3Tables(d);
    for (final e in defaults.entries) {
      await d.insert('settings', {'k': e.key, 'v': e.value});
    }
    for (var i = 0; i < classNames.length; i++) {
      final id = i + 1;
      await d.insert('classes',
          {'id': id, 'name': classNames[i], 'seat_start': id * 1000 + 1});
      for (final s in (id >= 10 ? secSubjects : basicSubjects)) {
        await d.insert('subjects', {'class_id': id, 'name': s});
      }
    }
  }

  // ---------- الإعدادات ----------
  static Future<String> setting(String k) async {
    final d = await get();
    final r = await d.query('settings', where: 'k=?', whereArgs: [k]);
    return r.isEmpty ? (defaults[k] ?? '') : r.first['v'] as String;
  }

  static Future<void> setSetting(String k, String v) async {
    final d = await get();
    await d.insert('settings', {'k': k, 'v': v},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------- استعلامات مساعدة ----------
  static Future<List<DbRow>> classes() async =>
      (await get()).query('classes', orderBy: 'id');

  static Future<String> className(int id) async {
    final r = await (await get())
        .query('classes', where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? '' : r.first['name'] as String;
  }

  static Future<List<DbRow>> subjectsOf(int classId) async =>
      (await get()).query('subjects',
          where: 'class_id=?', whereArgs: [classId], orderBy: 'id');

  static Future<List<String>> sectionsOf(int classId) async {
    final r = await (await get()).rawQuery(
        'SELECT DISTINCT section FROM students WHERE class_id=? ORDER BY section',
        [classId]);
    final out = [
      for (final e in r)
        if ((e['section'] as String?)?.isNotEmpty ?? false)
          e['section'] as String
    ];
    return out.isEmpty ? ['أ'] : out;
  }

  static Future<List<DbRow>> students(
      {int? classId, String? section, String q = ''}) async {
    final where = <String>[];
    final args = <Object?>[];
    if (classId != null) {
      where.add('class_id=?');
      args.add(classId);
    }
    if (section != null) {
      where.add('section=?');
      args.add(section);
    }
    if (q.trim().isNotEmpty) {
      where.add('(name LIKE ? OR CAST(reg_no AS TEXT) LIKE ?)');
      args.addAll(['%${q.trim()}%', '%${q.trim()}%']);
    }
    return (await get()).query('students',
        where: where.isEmpty ? null : where.join(' AND '),
        whereArgs: args,
        orderBy: 'class_id, section, seat_no, id');
  }

  static Future<int> count(String sql, [List<Object?>? args]) async =>
      Sqflite.firstIntValue(await (await get()).rawQuery(sql, args)) ?? 0;

  // ---------- الطلاب ----------
  /// عدد الطلاب الذين تغيّر رقم جلوسهم في آخر إعادة ترقيم.
  static int lastSeatShift = 0;

  static Future<int> addStudent(DbRow m, {bool reseat = true}) async {
    await License.ensureCanAdd();
    final d = await get();
    final id = await d.insert('students', m);
    await d.update('students', {'reg_no': m['reg_no'] ?? 1000 + id},
        where: 'id=?', whereArgs: [id]);
    if (reseat) await assignSeats(m['class_id'] as int);
    return id;
  }

  static Future<void> updateStudent(int id, DbRow m) async {
    final d = await get();
    final old = await d.query('students', columns: ['class_id'], where: 'id=?', whereArgs: [id]);
    await d.update('students', m, where: 'id=?', whereArgs: [id]);
    if (m['class_id'] != null) {
      await assignSeats(m['class_id'] as int);
      final oldClass = old.isEmpty ? null : old.first['class_id'] as int?;
      if (oldClass != null && oldClass != m['class_id']) await assignSeats(oldClass);
    }
  }

  static Future<void> deleteStudent(int id) async {
    final d = await get();
    final r = await d.query('students', where: 'id=?', whereArgs: [id]);
    for (final t in ['grades', 'monthly', 'attendance']) {
      await d.delete(t, where: 'student_id=?', whereArgs: [id]);
    }
    await d.delete('students', where: 'id=?', whereArgs: [id]);
    if (r.isNotEmpty) await assignSeats(r.first['class_id'] as int);
  }

  /// يعيد ترقيم الجلوس للصف: أبجدياً (الافتراضي) أو حسب ترتيب القيد.
  /// يعيد عدد الطلاب الذين تغيّر رقمهم.
  static Future<int> assignSeats(int classId, {String? order}) async {
    final d = await get();
    final cls = await d.query('classes', where: 'id=?', whereArgs: [classId]);
    if (cls.isEmpty) return 0;
    final start = cls.first['seat_start'] as int;
    final mode = order ?? await setting('seat_order');
    final st = await d.query('students',
        columns: ['id', 'name', 'seat_no'],
        where: 'class_id=?',
        whereArgs: [classId]);
    final list = [...st];
    if (mode == 'reg') {
      list.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    } else {
      list.sort((a, b) {
        final c = alphaKey('${a['name']}').compareTo(alphaKey('${b['name']}'));
        return c != 0 ? c : (a['id'] as int).compareTo(b['id'] as int);
      });
    }
    var changed = 0;
    final batch = d.batch();
    for (var i = 0; i < list.length; i++) {
      final seat = start + i;
      if (list[i]['seat_no'] != seat) {
        changed++;
        batch.update('students', {'seat_no': seat},
            where: 'id=?', whereArgs: [list[i]['id']]);
      }
    }
    await batch.commit(noResult: true);
    lastSeatShift = changed;
    return changed;
  }

  /// يعيد ترقيم الجلوس لكل الصفوف؛ يعيد إجمالي من تغيّر رقمه.
  static Future<int> reseatAll({String? order}) async {
    var total = 0;
    for (final c in await classes()) {
      total += await assignSeats(c['id'] as int, order: order);
    }
    return total;
  }

  /// رقم جلوس طالب.
  static Future<int?> seatOf(int id) async {
    final r = await (await get())
        .query('students', columns: ['seat_no'], where: 'id=?', whereArgs: [id]);
    return r.isEmpty ? null : r.first['seat_no'] as int?;
  }

  // ---------- الدرجات ----------
  static Future<void> saveGrade(
      int sid, int subId, String col, double? val) async {
    final d = await get();
    await d.insert('grades', {'student_id': sid, 'subject_id': subId},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await d.update('grades', {col: val},
        where: 'student_id=? AND subject_id=?', whereArgs: [sid, subId]);
  }

  static Future<void> saveMonthly(
      int sid, int subId, int month, String col, double? val) async {
    final d = await get();
    await d.insert(
        'monthly', {'student_id': sid, 'subject_id': subId, 'month': month},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await d.update('monthly', {col: val},
        where: 'student_id=? AND subject_id=? AND month=?',
        whereArgs: [sid, subId, month]);
  }

  // ---------- الحضور ----------
  static Future<void> setAttendance(int sid, String date, String? status) async {
    final d = await get();
    if (status == null) {
      await d.delete('attendance',
          where: 'student_id=? AND date=?', whereArgs: [sid, date]);
    } else {
      await d.insert(
          'attendance', {'student_id': sid, 'date': date, 'status': status},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  static Future<Map<int, String>> attendanceOn(String date) async {
    final r = await (await get())
        .query('attendance', where: 'date=?', whereArgs: [date]);
    return {for (final e in r) e['student_id'] as int: e['status'] as String};
  }

  // ---------- اللجان ----------
  /// توزيع الطلاب على اللجان لجميع الصفوف بترقيم متسلسل.
  static Future<int> distributeCommittees(int capacity, bool separate) async {
    final d = await get();
    final classes = await d.query('classes', orderBy: 'id');
    var counter = 0;
    await d.update('students', {'committee_no': null});
    for (final c in classes) {
      final cid = c['id'] as int;
      await assignSeats(cid);
      final st = await d.query('students',
          where: 'class_id=?', whereArgs: [cid], orderBy: 'seat_no, id');
      if (st.isEmpty) continue;
      final groups = separate
          ? [
              st.where((s) => s['gender'] != 'أنثى').toList(),
              st.where((s) => s['gender'] == 'أنثى').toList(),
            ]
          : [st];
      for (final g in groups) {
        var i = 0;
        for (final size in splitSizes(g.length, capacity)) {
          counter++;
          for (var k = 0; k < size; k++) {
            await d.update('students', {'committee_no': counter},
                where: 'id=?', whereArgs: [g[i++]['id']]);
          }
        }
      }
    }
    return counter;
  }

  // ---------- نسخ احتياطي ----------
  static Future<Map<String, Object?>> exportAll() async {
    final d = await get();
    return {
      'app': 'school_control',
      'version': 3,
      for (final t in _tables) t: await d.query(t),
    };
  }

  static Future<void> importAll(Map<String, dynamic> data) async {
    if (data['app'] != 'school_control') {
      throw const FormatException('ملف نسخة احتياطية غير صالح');
    }
    final d = await get();
    await d.transaction((txn) async {
      for (final t in _tables) {
        await txn.delete(t);
        final rows = (data[t] as List?) ?? [];
        for (final r in rows) {
          await txn.insert(t, Map<String, Object?>.from(r as Map));
        }
      }
    });
  }

  static Future<void> wipeData() async {
    final d = await get();
    for (final t in ['students', 'grades', 'monthly', 'attendance']) {
      await d.delete(t);
    }
  }

  // ---------- صفوف الرصد ----------
  static Future<List<DbRow>> gradeRows(int classId, String? section, int subjectId) async {
    final args = <Object?>[subjectId, classId];
    var sql = '''SELECT s.id, s.name, s.reg_no, s.seat_no, s.section,
        g.t1_work, g.t1_exam, g.t2_work, g.t2_exam
      FROM students s LEFT JOIN grades g
        ON g.student_id=s.id AND g.subject_id=?
      WHERE s.class_id=?''';
    if (section != null) {
      sql += ' AND s.section=?';
      args.add(section);
    }
    sql += ' ORDER BY s.seat_no, s.id';
    return (await get()).rawQuery(sql, args);
  }

  static Future<List<DbRow>> monthlyRows(
      int classId, String? section, int subjectId, int month) async {
    final args = <Object?>[subjectId, month, classId];
    var sql = '''SELECT s.id, s.name, s.reg_no, s.seat_no, s.section,
        m.hw, m.att, m.oral, m.written
      FROM students s LEFT JOIN monthly m
        ON m.student_id=s.id AND m.subject_id=? AND m.month=?
      WHERE s.class_id=?''';
    if (section != null) {
      sql += ' AND s.section=?';
      args.add(section);
    }
    sql += ' ORDER BY s.seat_no, s.id';
    return (await get()).rawQuery(sql, args);
  }
}
