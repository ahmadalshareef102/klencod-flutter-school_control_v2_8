import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_info.dart';
import '../db.dart';
import '../license.dart';
import '../widgets.dart';
import 'about_screen.dart';

/// يرسل طلب التفعيل (برقم الجهاز وبيانات المدرسة) للمطور.
Future<void> requestActivation(BuildContext context) async {
  final msg = await License.requestMessage();
  if (!context.mounted) return;
  final v = await showOptions<String>(context, 'إرسال طلب التفعيل للمطور', const [
    Opt(Icons.chat, 'واتساب', 'wa', 'يرسل رقم الجهاز وبياناتك مباشرة'),
    Opt(Icons.email_outlined, 'بريد إلكتروني', 'mail'),
    Opt(Icons.copy, 'نسخ نص الطلب', 'copy', 'لإرساله بأي طريقة تناسبك'),
  ]);
  if (v == null || !context.mounted) return;
  if (v == 'wa') {
    openUrl(context, 'https://wa.me/${AppInfo.whatsapp}?text=${Uri.encodeComponent(msg)}');
  } else if (v == 'mail') {
    openUrl(
        context,
        'mailto:${AppInfo.email}?subject=${Uri.encodeComponent('طلب تفعيل ${AppInfo.appName}')}'
        '&body=${Uri.encodeComponent(msg)}');
  } else {
    await Clipboard.setData(ClipboardData(text: msg));
    if (context.mounted) toast(context, 'تم نسخ نص الطلب');
  }
}

/// نافذة تظهر عند بلوغ حد الطلاب.
Future<void> showLimitDialog(BuildContext context, int limit) async {
  final v = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline, size: 36),
      title: const Text('بلغت الحد الأقصى للنسخة'),
      content: Text(
          'وصل عدد الطلاب إلى $limit وهو الحد المسموح به في هذه النسخة.\n'
          'للمتابعة تواصل مع المطور ${AppInfo.developer} لتفعيل التطبيق على جهازك، '
          'وسيرسل لك كود التفعيل.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'code'), child: const Text('لدي كود تفعيل')),
        FilledButton(onPressed: () => Navigator.pop(ctx, 'ask'), child: const Text('تواصل مع المطور')),
      ],
    ),
  );
  if (!context.mounted) return;
  if (v == 'ask') await requestActivation(context);
  if (v == 'code') await open(context, const LicenseScreen());
}

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({super.key});
  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final code = TextEditingController();
  LicenseState? st;
  String devId = '';
  int students = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    st = await License.state();
    devId = License.pretty(await License.deviceId());
    students = await Db.count('SELECT COUNT(*) FROM students');
    if (mounted) setState(() {});
  }

  Future<void> _activate() async {
    final ok = await License.activate(code.text);
    if (!mounted) return;
    if (ok) {
      code.clear();
      toast(context, 'تم التفعيل بنجاح');
    } else {
      toast(context, 'الكود غير صحيح لهذا الجهاز');
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = st;
    final cs = Theme.of(context).colorScheme;
    if (s == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final ok = s.activated;
    final progress = s.unlimited ? 0.0 : (students / s.limit).clamp(0.0, 1.0);
    return Scaffold(
      appBar: AppBar(title: const Text('الترخيص والتفعيل')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(ok ? Icons.verified : Icons.lock_open,
                    color: ok ? Colors.green : Colors.orange),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(s.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 10),
              if (!s.unlimited) ...[
                LinearProgressIndicator(value: progress, minHeight: 8),
                const SizedBox(height: 6),
                Text('عدد الطلاب: $students من ${s.limit}'),
              ] else
                Text('عدد الطلاب: $students'),
              if (s.expiry != null)
                Text('ينتهي التفعيل في: ${s.expiry!.year}-${s.expiry!.month.toString().padLeft(2, '0')}-${s.expiry!.day.toString().padLeft(2, '0')}'),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('رقم هذا الجهاز', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: cs.primaryContainer.withOpacity(.4),
                    borderRadius: BorderRadius.circular(12)),
                child: SelectableText(devId,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: devId));
                      if (context.mounted) toast(context, 'تم نسخ رقم الجهاز');
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('نسخ الرقم'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => requestActivation(context),
                    icon: const Icon(Icons.send),
                    label: const Text('اطلب التفعيل'),
                  ),
                ),
              ]),
              const SizedBox(height: 6),
              Text('اضغط «اطلب التفعيل» ليُرسل رقم الجهاز وبيانات المدرسة إلى المطور '
                  '${AppInfo.developer} (${AppInfo.phone}).',
                  style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إدخال كود التفعيل', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: code,
                textDirection: TextDirection.ltr,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(hintText: 'U-0-XXXX-XXXX-XXXX-XXXX'),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: _activate,
                    icon: const Icon(Icons.vpn_key),
                    label: const Text('تفعيل')),
              ),
              if (ok || s.expired)
                TextButton(
                  onPressed: () async {
                    if (await confirmDialog(context, 'إلغاء التفعيل على هذا الجهاز؟',
                        ok: 'إلغاء التفعيل', danger: true)) {
                      await License.deactivate();
                      _load();
                    }
                  },
                  child: const Text('إلغاء التفعيل'),
                ),
            ]),
          ),
        ),
      ]),
    );
  }
}
