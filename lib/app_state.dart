import 'package:flutter/material.dart';
import 'db.dart';
import 'fonts.dart';

/// تفضيلات الشكل: اللون والخلفية والأشكال والخط.
class LookPrefs {
  final Color accent;
  final int darkBg, lightBg; // 0..3
  final double radius; // نصف قطر الزوايا
  final int cardStyle; // 0 بإطار، 1 بظل، 2 ممتلئ
  final bool outlinedInputs, compact;
  final double scale; // تكبير الخط
  final String titleFont; // same أو معرّف خط
  const LookPrefs({
    this.accent = const Color(0xFFDB2777),
    this.darkBg = 0,
    this.lightBg = 1,
    this.radius = 28,
    this.cardStyle = 0,
    this.outlinedInputs = false,
    this.compact = false,
    this.scale = 1.0,
    this.titleFont = 'same',
  });

  LookPrefs copyWith({
    Color? accent, int? darkBg, int? lightBg, double? radius, int? cardStyle,
    bool? outlinedInputs, bool? compact, double? scale, String? titleFont,
  }) =>
      LookPrefs(
        accent: accent ?? this.accent,
        darkBg: darkBg ?? this.darkBg,
        lightBg: lightBg ?? this.lightBg,
        radius: radius ?? this.radius,
        cardStyle: cardStyle ?? this.cardStyle,
        outlinedInputs: outlinedInputs ?? this.outlinedInputs,
        compact: compact ?? this.compact,
        scale: scale ?? this.scale,
        titleFont: titleFont ?? this.titleFont,
      );
}

/// حالة عامة خفيفة: المظهر والخط والتقويم.
class AppState {
  static final themeMode = ValueNotifier<ThemeMode>(ThemeMode.light);
  static final hijri = ValueNotifier<bool>(true);
  /// معرّف خط النص (انظر fonts.dart).
  static final font = ValueNotifier<String>('system');
  static final look = ValueNotifier<LookPrefs>(const LookPrefs());
  static int hijriOffset = 0;

  static Future<void> load() async {
    final t = await Db.setting('theme');
    themeMode.value = t == 'dark'
        ? ThemeMode.dark
        : t == 'system'
            ? ThemeMode.system
            : ThemeMode.light;
    font.value = fontById(await Db.setting('font')).id;
    hijri.value = (await Db.setting('calendar')) != 'gregorian';
    hijriOffset = int.tryParse(await Db.setting('hijri_offset')) ?? 0;
    double d(String v, double def) => double.tryParse(v) ?? def;
    final acc = int.tryParse(await Db.setting('accent'));
    look.value = LookPrefs(
      accent: acc == null ? const Color(0xFFDB2777) : Color(acc),
      darkBg: (int.tryParse(await Db.setting('bg_dark')) ?? 0).clamp(0, 3),
      lightBg: (int.tryParse(await Db.setting('bg_light')) ?? 1).clamp(0, 3),
      radius: d(await Db.setting('radius'), 28).clamp(0, 32).toDouble(),
      cardStyle: (int.tryParse(await Db.setting('card_style')) ?? 0).clamp(0, 2),
      outlinedInputs: (await Db.setting('input_outlined')) == '1',
      compact: (await Db.setting('compact')) == '1',
      scale: d(await Db.setting('font_scale'), 1).clamp(0.8, 1.5).toDouble(),
      titleFont: await Db.setting('font_title'),
    );
  }

  /// يطبّق تفضيلات الشكل فوراً، ويحفظها عند [save].
  static Future<void> setLook(LookPrefs l, {bool save = true}) async {
    look.value = l;
    if (!save) return;
    await Db.setSetting('accent', '${l.accent.toARGB32()}');
    await Db.setSetting('bg_dark', '${l.darkBg}');
    await Db.setSetting('bg_light', '${l.lightBg}');
    await Db.setSetting('radius', '${l.radius}');
    await Db.setSetting('card_style', '${l.cardStyle}');
    await Db.setSetting('input_outlined', l.outlinedInputs ? '1' : '0');
    await Db.setSetting('compact', l.compact ? '1' : '0');
    await Db.setSetting('font_scale', '${l.scale}');
    await Db.setSetting('font_title', l.titleFont);
  }

  static Future<void> setFont(String id) async {
    font.value = id;
    await Db.setSetting('font', id);
  }

  static Future<void> setThemeMode(ThemeMode m) async {
    themeMode.value = m;
    await Db.setSetting(
        'theme', m == ThemeMode.light ? 'light' : m == ThemeMode.system ? 'system' : 'dark');
  }
}
