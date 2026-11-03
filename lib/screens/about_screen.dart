import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_info.dart';
import '../widgets.dart';

Future<void> openUrl(BuildContext context, String url) async {
  try {
    final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) toast(context, 'تعذر فتح الرابط');
  } catch (_) {
    if (context.mounted) toast(context, 'تعذر فتح الرابط');
  }
}

/// بطاقة المطور مع أزرار الاتصال والواتساب والبريد.
class DeveloperCard extends StatelessWidget {
  const DeveloperCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget action(IconData i, String tip, Color c, VoidCallback f) => IconButton(
          tooltip: tip,
          icon: Icon(i, color: c, size: 28),
          onPressed: f,
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset('assets/developer.png', fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المطور: ${AppInfo.developer}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(AppInfo.phone,
                    style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold)),
                Text(AppInfo.email, style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            action(Icons.call, 'اتصال', Colors.blue,
                () => openUrl(context, 'tel:${AppInfo.phone}')),
            action(Icons.chat, 'واتساب', Colors.green,
                () => openUrl(context, 'https://wa.me/${AppInfo.whatsapp}')),
            action(Icons.email_outlined, 'بريد إلكتروني', Colors.orange,
                () => openUrl(context, 'mailto:${AppInfo.email}')),
            action(Icons.copy, 'نسخ الرقم', cs.primary, () async {
              await Clipboard.setData(const ClipboardData(text: AppInfo.phone));
              if (context.mounted) toast(context, 'تم نسخ الرقم');
            }),
          ]),
        ]),
      ),
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('عن التطبيق والمطور')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset('assets/icon.png', width: 84, height: 84),
                ),
                const SizedBox(height: 8),
                const Text(AppInfo.appName,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text('الإصدار ${AppInfo.version}'),
                const SizedBox(height: 8),
                Text(
                    'نظام كنترول مدرسي متكامل: القيد والحضور والدرجات والنتائج واللجان والشهادات والتقارير.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.asset('assets/developer.png', height: 150, fit: BoxFit.contain),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const DeveloperCard(),
        ]),
      );
}
