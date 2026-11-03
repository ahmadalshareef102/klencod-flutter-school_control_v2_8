import 'package:flutter/material.dart';
import 'app_state.dart';
import 'db.dart';
import 'dates.dart';

Future<T?> open<T>(BuildContext c, Widget w) =>
    Navigator.push<T>(c, MaterialPageRoute(builder: (_) => w));

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmDialog(BuildContext c, String msg,
    {String ok = 'تأكيد', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: c,
    builder: (_) => AlertDialog(
      content: Text(msg),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c, false), child: const Text('إلغاء')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(backgroundColor: Colors.red.shade600)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return r ?? false;
}

class Opt<T> {
  final IconData icon;
  final String title;
  final T value;
  final String? sub;
  const Opt(this.icon, this.title, this.value, [this.sub]);
}

Future<T?> showOptions<T>(BuildContext c, String title, List<Opt<T>> opts) =>
    showModalBottomSheet<T>(
      context: c,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * .8),
          child: ListView(shrinkWrap: true, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
            ),
            for (final o in opts)
              ListTile(
                leading: Icon(o.icon),
                title: Text(o.title),
                subtitle: o.sub == null ? null : Text(o.sub!),
                onTap: () => Navigator.pop(ctx, o.value),
              ),
          ]),
        ),
      ),
    );

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const PageHeader(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: t.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            if (subtitle != null)
              Text(subtitle!,
                  style: t.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.primary)),
          ]),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const StatTile(this.label, this.value, this.icon, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.bold)),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      );
}

class SectionTile extends StatelessWidget {
  final String title, sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  const SectionTile(this.title, this.sub, this.icon, this.color,
      {super.key, required this.onTap, this.onLongPress});

  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: color.withOpacity(.18),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              Text(sub,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class Pick<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  const Pick(
      {super.key,
      required this.label,
      required this.value,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) => InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
              isExpanded: true, value: value, items: items, onChanged: onChanged),
        ),
      );
}

/// نطاق الاختيار: صف + شعبة + مادة + شهر.
class Scope {
  final int classId;
  final String? section;
  final int? subjectId;
  final int month;
  const Scope(this.classId, this.section, this.subjectId, this.month);
}

class ScopeBar extends StatefulWidget {
  final bool subject, month;
  final int? initialClass;
  final int monthFrom, monthTo;
  final ValueChanged<Scope> onChanged;
  const ScopeBar(
      {super.key,
      this.subject = false,
      this.month = false,
      this.monthFrom = 1,
      this.monthTo = 12,
      this.initialClass,
      required this.onChanged});

  @override
  State<ScopeBar> createState() => _ScopeBarState();
}

class _ScopeBarState extends State<ScopeBar> {
  List<DbRow> classes = [], subjects = [];
  List<String> sections = [];
  int classId = 1;
  String? section;
  int? subjectId;
  int month = 1;

  @override
  void initState() {
    super.initState();
    classId = widget.initialClass ?? 1;
    month = widget.monthFrom;
    _init();
  }

  Future<void> _init() async {
    classes = await Db.classes();
    await _loadClass();
  }

  Future<void> _loadClass() async {
    subjects = await Db.subjectsOf(classId);
    sections = await Db.sectionsOf(classId);
    if (!subjects.any((s) => s['id'] == subjectId)) {
      subjectId = subjects.isEmpty ? null : subjects.first['id'] as int;
    }
    if (section != null && !sections.contains(section)) section = null;
    if (mounted) setState(() {});
    _emit();
  }

  void _emit() => widget.onChanged(Scope(classId, section, subjectId, month));

  @override
  Widget build(BuildContext context) {
    if (classes.isEmpty) return const SizedBox(height: 56);
    final hijri = AppState.hijri.value;
    return Column(children: [
      Row(children: [
        Expanded(
          child: Pick<int>(
            label: 'الصف',
            value: classId,
            items: [
              for (final c in classes)
                DropdownMenuItem(
                    value: c['id'] as int, child: Text(c['name'] as String))
            ],
            onChanged: (v) {
              classId = v!;
              subjectId = null;
              _loadClass();
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Pick<String?>(
            label: 'الفصل / الشعبة',
            value: section,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('كل الشعب')),
              for (final s in sections)
                DropdownMenuItem<String?>(value: s, child: Text(s)),
            ],
            onChanged: (v) {
              setState(() => section = v);
              _emit();
            },
          ),
        ),
      ]),
      if (widget.subject) ...[
        const SizedBox(height: 8),
        Pick<int>(
          label: 'المادة',
          value: subjectId,
          items: [
            for (final s in subjects)
              DropdownMenuItem(
                  value: s['id'] as int, child: Text(s['name'] as String))
          ],
          onChanged: (v) {
            setState(() => subjectId = v);
            _emit();
          },
        ),
      ],
      if (widget.month) ...[
        const SizedBox(height: 8),
        Pick<int>(
          label: 'الشهر',
          value: month,
          items: [
            for (var m = widget.monthFrom; m <= widget.monthTo; m++)
              DropdownMenuItem(value: m, child: Text(monthName(m, hijri)))
          ],
          onChanged: (v) {
            setState(() => month = v!);
            _emit();
          },
        ),
      ],
    ]);
  }
}
