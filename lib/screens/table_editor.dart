import 'package:flutter/material.dart';
import '../data_io.dart';
import '../widgets.dart';

/// محرر وعارض جداول: تعديل الخلايا والعناوين، وإضافة/حذف صفوف وأعمدة،
/// ثم التصدير، أو تطبيق الجدول في النظام (عند تمرير [onApply]).
class TableEditorScreen extends StatefulWidget {
  final ExportTable table;
  final Future<String> Function(List<List<String>> rowsWithHeader)? onApply;
  const TableEditorScreen({super.key, required this.table, this.onApply});

  @override
  State<TableEditorScreen> createState() => _TableEditorState();
}

class _TableEditorState extends State<TableEditorScreen> {
  late List<String> heads = [...widget.table.heads];
  late List<List<String>> rows = [
    for (final r in widget.table.rows)
      [for (var i = 0; i < widget.table.heads.length; i++) i < r.length ? r[i] : '']
  ];

  Future<void> _edit(String title, String initial, ValueChanged<String> done) async {
    final c = TextEditingController(text: initial);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, maxLines: null),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok == true) setState(() => done(c.text));
  }

  Future<void> _export() async {
    final v = await showOptions<bool>(context, 'حفظ وتصدير الملف', const [
      Opt(Icons.table_chart, 'Excel (xlsx)', true),
      Opt(Icons.description_outlined, 'CSV بترميز UTF-8', false),
    ]);
    if (v == null) return;
    try {
      await exportTable(ExportTable(widget.table.title, heads, rows), xlsx: v);
    } catch (e) {
      if (mounted) toast(context, 'تعذر التصدير: $e');
    }
  }

  Future<void> _apply() async {
    try {
      final msg = await widget.onApply!([heads, ...rows]);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('نتيجة التطبيق'),
          content: Text(msg),
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('حسناً'))],
        ),
      );
    } catch (e) {
      if (mounted) toast(context, 'تعذر التطبيق: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('محرر وعارض جداول الإكسل'),
        backgroundColor: cs.primaryContainer,
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(widget.table.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  Text('${rows.length} صف × ${heads.length} عمود',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                Text('انقر على أي خلية أو عنوان عمود لتعديل محتواه مباشرة',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    FilledButton.icon(
                      onPressed: () => setState(() => rows.add(List<String>.generate(heads.length, (_) => ''))),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة صف'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        heads.add('عمود جديد');
                        for (final r in rows) {
                          r.add('');
                        }
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة عمود'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: rows.isEmpty ? null : () => setState(() => rows.removeLast()),
                      child: const Text('حذف آخر صف'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: heads.length <= 1
                          ? null
                          : () => setState(() {
                                heads.removeLast();
                                for (final r in rows) {
                                  r.removeLast();
                                }
                              }),
                      child: const Text('حذف آخر عمود'),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: heads.isEmpty
              ? const Center(child: Text('الجدول فارغ'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 18,
                      headingRowColor: WidgetStatePropertyAll(cs.primary.withOpacity(.22)),
                      columns: [
                        const DataColumn(label: Text('#')),
                        for (var c = 0; c < heads.length; c++)
                          DataColumn(
                            label: InkWell(
                              onTap: () => _edit('تعديل عنوان العمود', heads[c], (v) => heads[c] = v),
                              child: Text(heads[c], style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                      ],
                      rows: [
                        for (var r = 0; r < rows.length; r++)
                          DataRow(cells: [
                            DataCell(Text('${r + 1}')),
                            for (var c = 0; c < heads.length; c++)
                              DataCell(
                                Text(rows[r][c]),
                                showEditIcon: false,
                                onTap: () => _edit('تعديل الخلية (صف ${r + 1})', rows[r][c], (v) => rows[r][c] = v),
                              ),
                          ]),
                      ],
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(top: BorderSide(color: cs.outlineVariant))),
          child: Row(children: [
            if (widget.onApply != null) ...[
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: _apply,
                  icon: const Icon(Icons.download_done),
                  label: const Text('استيراد وتطبيق في النظام'),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary),
                onPressed: _export,
                icon: const Icon(Icons.save_alt),
                label: const Text('حفظ وتصدير (XLSX / CSV)'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
