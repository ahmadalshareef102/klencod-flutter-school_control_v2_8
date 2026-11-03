import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'app_info.dart';

/// فحص التحديثات: يقرأ version.json من GitHub ويعرض نافذة إن وُجد إصدار أحدث.
class Updater {
  static const repo = 'klencod-flutter-school_control_v2';
  static const versionUrl =
      'https://raw.githubusercontent.com/ahmadalshareef102/$repo/main/version.json';
  static const defaultDownload = 'https://github.com/ahmadalshareef102/$repo/releases/latest';
  static const defaultGithub = 'https://github.com/ahmadalshareef102/$repo/releases';
  static const defaultTelegram = 'https://t.me/ahmadalshareef102';

  static bool _checked = false;

  static List<int> _parts(String v) =>
      v.split('+').first.split('.').map((e) => int.tryParse(e.trim()) ?? 0).toList();

  static bool isNewer(String remote, String local) {
    final a = _parts(remote), b = _parts(local);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0, y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static Future<Map<String, dynamic>?> _fetch() async {
    final c = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      final req = await c.getUrl(Uri.parse('$versionUrl?t=${DateTime.now().millisecondsSinceEpoch}'));
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = await res.transform(utf8.decoder).join();
      final j = jsonDecode(body);
      return j is Map<String, dynamic> ? j : null;
    } catch (_) {
      return null;
    } finally {
      c.close(force: true);
    }
  }

  static Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// يُستدعى عند فتح التطبيق (مرة واحدة)، ولا يزعج المستخدم عند غياب الإنترنت.
  static Future<void> check(BuildContext context, {bool manual = false}) async {
    if (_checked && !manual) return;
    _checked = true;
    final j = await _fetch();
    if (!context.mounted) return;
    if (j == null) {
      if (manual) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تعذر الاتصال بخادم التحديثات')));
      }
      return;
    }
    final v = '${j['version'] ?? ''}';
    if (v.isEmpty || !isNewer(v, AppInfo.version)) {
      if (manual) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('أنت تستخدم أحدث إصدار ✓')));
      }
      return;
    }
    final required = j['required'] == true;
    final notes = '${j['notes'] ?? ''}';
    final download = '${j['download'] ?? defaultDownload}';
    final github = '${j['github'] ?? defaultGithub}';
    final telegram = '${j['telegram'] ?? defaultTelegram}';
    await showDialog<void>(
      context: context,
      barrierDismissible: !required,
      builder: (ctx) => PopScope(
        canPop: !required,
        child: AlertDialog(
          title: const Text('تحديث متوفر', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.cloud_download, size: 56),
              const SizedBox(height: 10),
              Text('الإصدار الحالي: ${AppInfo.version}  ←  الجديد: $v',
                  textAlign: TextAlign.center),
              if (required) ...[
                const SizedBox(height: 10),
                const Text('هذا التحديث مطلوب لمواصلة استخدام التطبيق',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.redAccent)),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text('ما الجديد في هذا التحديث؟',
                        style: TextStyle(fontWeight: FontWeight.bold))),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text(notes),
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: () => _open(download),
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('تحديث الآن')),
              ),
              const SizedBox(height: 10),
              const Text('مصادر تحميل أخرى'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _open(github), child: const Text('GitHub'))),
                const SizedBox(width: 8),
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => _open(telegram), child: const Text('Telegram'))),
              ]),
              const SizedBox(height: 8),
              const Text('ثبّت فوق النسخة القديمة للحفاظ على البيانات.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
            ]),
          ),
          actions: [
            if (!required)
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لاحقاً')),
          ],
        ),
      ),
    );
  }
}
