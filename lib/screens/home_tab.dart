import 'package:flutter/material.dart';
import '../app_info.dart';
import '../app_state.dart';
import '../data_io.dart';
import '../dates.dart';
import '../db.dart';
import '../widgets.dart';
import '../license.dart';
import 'about_screen.dart';
import 'license_screen.dart';
import 'attendance_screen.dart';
import 'committees.dart';
import 'excel_center.dart';
import 'results.dart';
import 'settings_tab.dart';
import 'stats.dart';
import 'student_form.dart';

class HomeTab extends StatefulWidget {
  final void Function(int) go;
  const HomeTab({super.key, required this.go});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int students = 0, subjects = 0, present = 0, absent = 0;
  String teacher = '', school = '', year = '';
  LicenseState? lic;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final today = isoDate(DateTime.now());
    students = await Db.count('SELECT COUNT(*) FROM students');
    subjects = await Db.count('SELECT COUNT(DISTINCT name) FROM subjects');
    present = await Db.count(
        "SELECT COUNT(*) FROM attendance WHERE date=? AND status IN ('حاضر','متأخر')", [today]);
    absent = await Db.count(
        "SELECT COUNT(*) FROM attendance WHERE date=? AND status='غائب'", [today]);
    lic = await License.state();
    teacher = await Db.setting('teacher');
    school = await Db.setting('school');
    year = await Db.setting('year');
    if (mounted) setState(() {});
  }

  Future<void> _go(Widget w) async {
    await open(context, w);
    _load();
  }

  Future<void> _menu() async {
    final v = await showOptions<String>(context, 'القائمة', const [
      Opt(Icons.brightness_6, 'تبديل المظهر (داكن / فاتح)', 'theme'),
      Opt(Icons.cloud_upload_outlined, 'نسخة احتياطية الآن', 'backup'),
      Opt(Icons.table_chart_outlined, 'مركز Excel و CSV', 'excel'),
      Opt(Icons.settings_outlined, 'الإعدادات', 'settings'),
    ]);
    if (v == null || !mounted) return;
    switch (v) {
      case 'theme':
        final dark = AppState.themeMode.value != ThemeMode.light;
        AppState.themeMode.value = dark ? ThemeMode.light : ThemeMode.dark;
        await Db.setSetting('theme', dark ? 'light' : 'dark');
      case 'backup':
        await backupNow(context);
      case 'excel':
        _go(const ExcelCenter());
      case 'settings':
        widget.go(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final today = fmtDate(DateTime.now(),
        hijri: AppState.hijri.value, offset: AppState.hijriOffset);
    final tiles = <(String, String, IconData, Color, VoidCallback, List<Opt<VoidCallback>>)>[
      (
        'الطلاب', 'قيد وبيانات الطلاب', Icons.groups, Colors.blue,
        () => widget.go(1),
        [
          Opt<VoidCallback>(Icons.person_add, 'إضافة طالب', () => _go(const StudentForm())),
          Opt<VoidCallback>(Icons.upload_file, 'استيراد طلاب', () => _go(const ExcelCenter(initialTab: 1))),
          Opt<VoidCallback>(Icons.download, 'تصدير الطلاب', () => _go(const ExcelCenter())),
        ]
      ),
      (
        'الحضور', 'تحضير يومي وتقارير', Icons.event_available, Colors.teal,
        () => _go(const AttendanceScreen()),
        [
          Opt<VoidCallback>(Icons.how_to_reg, 'تسجيل حضور اليوم', () => _go(const AttendanceScreen())),
        ]
      ),
      (
        'الدرجات', 'رصد فصلي وشهري', Icons.grading, Colors.orange,
        () => widget.go(2),
        [
          Opt<VoidCallback>(Icons.edit_note, 'الرصد الفصلي والشهري', () => widget.go(2)),
          Opt<VoidCallback>(Icons.leaderboard, 'النتائج والترتيب', () => _go(const ResultsScreen())),
        ]
      ),
      (
        'اللجان والجلوس', 'أرقام وكشوف المناداة', Icons.event_seat, Colors.purple,
        () => _go(const CommitteesScreen()),
        [
          Opt<VoidCallback>(Icons.shuffle, 'توزيع اللجان', () => _go(const CommitteesScreen())),
        ]
      ),
      (
        'النتائج', 'ترتيب وتقدير وحالة', Icons.leaderboard, Colors.green,
        () => _go(const ResultsScreen()),
        [
          Opt<VoidCallback>(Icons.print, 'طباعة كشف النتائج', () => widget.go(3)),
          Opt<VoidCallback>(Icons.bar_chart, 'الإحصاءات', () => _go(const StatsScreen())),
        ]
      ),
      (
        'الإحصاءات', 'خلاصة نتائج الصفوف', Icons.bar_chart, Colors.pink,
        () => _go(const StatsScreen()),
        [
          Opt<VoidCallback>(Icons.table_chart, 'تصدير الإحصاء', () => _go(const StatsScreen())),
        ]
      ),
      (
        'التقارير', 'PDF وExcel وشهادات', Icons.print, Colors.cyan,
        () => widget.go(3),
        [
          Opt<VoidCallback>(Icons.print, 'التقارير والاستمارات', () => widget.go(3)),
          Opt<VoidCallback>(Icons.table_chart, 'مركز Excel', () => _go(const ExcelCenter())),
        ]
      ),
      (
        'الإعدادات', 'مواد وقواعد ونسخ', Icons.settings, Colors.blueGrey,
        () => widget.go(4),
        [
          Opt<VoidCallback>(Icons.settings, 'فتح الإعدادات', () => widget.go(4)),
          Opt<VoidCallback>(Icons.cloud_upload, 'نسخة احتياطية', () => backupNow(context)),
        ]
      ),
    ];

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(
                  radius: 26,
                  backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.person, color: cs.onPrimaryContainer)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(teacher.isEmpty ? 'أهلاً بك' : 'أهلاً بك يا $teacher',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text([school, 'العام الدراسي $year'].where((e) => e.isNotEmpty).join(' | '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.primary)),
                ]),
              ),
              IconButton(icon: const Icon(Icons.menu), onPressed: _menu),
            ]),
          ),
        ),
        if (lic != null && !lic!.unlimited && students >= lic!.limit * 0.7) ...[
          const SizedBox(height: 12),
          Card(
            color: Colors.orange.withOpacity(.18),
            child: ListTile(
              leading: const Icon(Icons.lock_clock, color: Colors.orange),
              title: Text(students >= lic!.limit
                  ? 'بلغت الحد الأقصى للنسخة (${lic!.limit} طالب)'
                  : 'النسخة المجانية: $students من ${lic!.limit} طالب'),
              subtitle: Text(lic!.expired
                  ? 'انتهت مدة التفعيل، تواصل مع المطور للتجديد'
                  : 'للمتابعة تواصل مع المطور لتفعيل التطبيق'),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => _go(const LicenseScreen()),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: StatTile('إجمالي الطلاب', '$students', Icons.groups, Colors.blue)),
          const SizedBox(width: 8),
          Expanded(child: StatTile('المواد الدراسية', '$subjects', Icons.menu_book, Colors.teal)),
          const SizedBox(width: 8),
          Expanded(child: StatTile('حضور اليوم', '$present / ${present + absent}', Icons.how_to_reg, Colors.orange)),
        ]),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(today),
            subtitle: const Text('اضغط للتبديل بين الهجري والميلادي'),
            onTap: () async {
              AppState.hijri.value = !AppState.hijri.value;
              await Db.setSetting('calendar', AppState.hijri.value ? 'hijri' : 'gregorian');
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 16),
        Text('إجراءات سريعة', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
              onPressed: () => _go(const AttendanceScreen()),
              icon: const Icon(Icons.event_available),
              label: const Text('تسجيل الحضور')),
          FilledButton.tonalIcon(
              onPressed: () => _go(const StudentForm()),
              icon: const Icon(Icons.person_add),
              label: const Text('إضافة طالب')),
          OutlinedButton.icon(
              onPressed: () => _go(const ExcelCenter()),
              icon: const Icon(Icons.table_chart),
              label: const Text('مركز Excel')),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          Text('الأقسام الرئيسية', style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          Text('اضغط مطولاً لخيارات القسم',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.25,
          children: [
            for (final t in tiles)
              SectionTile(t.$1, t.$2, t.$3, t.$4,
                  onTap: t.$5,
                  onLongPress: () async {
                    final act = await showOptions<VoidCallback>(context, t.$1, t.$6);
                    act?.call();
                  }),
          ],
        ),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => open(context, const AboutScreen()),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'المطور: ${AppInfo.developer} • ${AppInfo.phone}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
      ]),
    );
  }
}
