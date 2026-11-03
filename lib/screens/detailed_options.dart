import 'package:flutter/material.dart';
import '../report_engine.dart';

/// نافذة تخصيص ترويسة وأعمدة الكشف الشامل المفصل.
Future<DetailedOptions?> showDetailedOptions(
    BuildContext context, DetailedOptions initial) {
  final title = TextEditingController(text: initial.title);
  final year = TextEditingController(text: initial.year);
  final subject = TextEditingController(text: initial.subject);
  final teacher = TextEditingController(text: initial.teacher);
  var full = initial.full,
      regNo = initial.regNo,
      exam = initial.exam,
      rating = initial.rating,
      sign = initial.signatures;

  return showDialog<DetailedOptions>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) {
        final cs = Theme.of(ctx).colorScheme;
        Widget section(String t, List<Widget> kids) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: cs.primaryContainer.withOpacity(.25),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...kids,
              ]),
            );
        return AlertDialog(
          scrollable: true,
          title: const Text('تخصيص ترويسة وأعمدة ملف الإكسل'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('عدّل عنوان الكشف ومعلومات الترويسة، وتحكّم في تفاصيل الأعمدة المصدّرة.',
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            section('مستوى تفاصيل الدرجات الشهرية', [
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: true,
                groupValue: full,
                onChanged: (v) => set(() => full = v!),
                title: const Text('كشف شامل مفصل كامل'),
                subtitle: const Text('تفاصيل كل شهر: الواجبات والمواظبة والشفهي والتحريري والمحصلة'),
              ),
              RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                value: false,
                groupValue: full,
                onChanged: (v) => set(() => full = v!),
                title: const Text('كشف ملخص'),
                subtitle: const Text('مجموع ومحصلة كل شهر فقط دون المكونات'),
              ),
            ]),
            section('ترويسة وعنوان المستند', [
              TextField(
                controller: title,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'عنوان التقرير الرئيسي', hintText: 'اتركه فارغاً للعنوان التلقائي'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextField(
                      controller: subject,
                      decoration: const InputDecoration(labelText: 'المادة')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                      controller: year,
                      decoration: const InputDecoration(labelText: 'العام الدراسي')),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                  controller: teacher,
                  decoration: const InputDecoration(labelText: 'اسم المعلم')),
            ]),
            section('الأعمدة المضمنة في الملف', [
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('عمود رقم القيد / الهوية'),
                  value: regNo,
                  onChanged: (v) => set(() => regNo = v!)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('عمود اختبار منتصف الفصل'),
                  value: exam,
                  onChanged: (v) => set(() => exam = v!)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('عمود التقدير العام والنسبة المئوية'),
                  value: rating,
                  onChanged: (v) => set(() => rating = v!)),
              CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('صفوف التوقيع والختم الإداري أسفل الجدول'),
                  value: sign,
                  onChanged: (v) => set(() => sign = v!)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () => Navigator.pop(
                  ctx,
                  DetailedOptions(
                    full: full,
                    title: title.text.trim(),
                    year: year.text.trim(),
                    subject: subject.text.trim(),
                    teacher: teacher.text.trim(),
                    regNo: regNo,
                    exam: exam,
                    rating: rating,
                    signatures: sign,
                  )),
              child: const Text('اعتماد الإعدادات'),
            ),
          ],
        );
      },
    ),
  );
}
