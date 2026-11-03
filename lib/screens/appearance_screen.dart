import 'package:flutter/material.dart';
import '../app_state.dart';
import '../fonts.dart';
import '../main.dart';
import '../widgets.dart';

const _accents = <Color>[
  Color(0xFF1976D2), Color(0xFF0E9F6E), Color(0xFF0D9488), Color(0xFF7C3AED),
  Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF4F46E5), Color(0xFFDB2777),
  Color(0xFF8D6E63), Color(0xFF475569),
];

/// التحكم في المظهر: الوضع، اللون، الخلفية، الأشكال، الخطوط.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('المظهر والألوان والخطوط'), actions: [
          IconButton(
            tooltip: 'استعادة الافتراضي',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              if (!await confirmDialog(context, 'استعادة المظهر الافتراضي بالكامل؟')) return;
              await AppState.setLook(const LookPrefs());
              await AppState.setFont('cairo');
              await AppState.setThemeMode(ThemeMode.light);
            },
          ),
        ]),
        body: ListenableBuilder(
          listenable: Listenable.merge([AppState.look, AppState.font, AppState.themeMode]),
          builder: (context, _) => _Body(
            look: AppState.look.value,
            font: AppState.font.value,
            mode: AppState.themeMode.value,
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  final LookPrefs look;
  final String font;
  final ThemeMode mode;
  const _Body({required this.look, required this.font, required this.mode});

  Widget _title(BuildContext c, String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: Theme.of(c).textTheme.titleMedium),
          if (sub != null) Text(sub, style: Theme.of(c).textTheme.bodySmall),
        ]),
      );

  void _set(LookPrefs l, {bool save = true}) => AppState.setLook(l, save: save);

  Future<void> _customColor(BuildContext context) async {
    var hsl = HSLColor.fromColor(look.accent);
    final picked = await showDialog<Color>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final c = hsl.toColor();
          return AlertDialog(
            title: const Text('لون مخصص'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                height: 60,
                decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(14)),
              ),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('درجة اللون')),
              Slider(
                value: hsl.hue.clamp(0, 359).toDouble(),
                min: 0,
                max: 359,
                onChanged: (v) => set(() => hsl = hsl.withHue(v)),
              ),
              const Align(alignment: Alignment.centerRight, child: Text('التشبّع')),
              Slider(
                value: hsl.saturation.clamp(0.15, 1.0).toDouble(),
                min: 0.15,
                max: 1,
                onChanged: (v) => set(() => hsl = hsl.withSaturation(v)),
              ),
              const Align(alignment: Alignment.centerRight, child: Text('الإضاءة')),
              Slider(
                value: hsl.lightness.clamp(0.2, 0.7).toDouble(),
                min: 0.2,
                max: 0.7,
                onChanged: (v) => set(() => hsl = hsl.withLightness(v)),
              ),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
              FilledButton(onPressed: () => Navigator.pop(ctx, c), child: const Text('اعتماد')),
            ],
          );
        },
      ),
    );
    if (picked != null) _set(look.copyWith(accent: picked));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fontItems = [
      for (final f in appFonts)
        DropdownMenuItem(
          value: f.id,
          child: Text(
            '${f.label}${f.display ? '  •  للعناوين' : ''}',
            style: TextStyle(fontFamily: f.family, fontSize: 15 * f.adjust),
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
      // ---------- معاينة ----------
      _title(context, 'معاينة مباشرة'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الكنترول المدرسي', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('رصد الدرجات والحضور واللجان والشهادات • 1234567890',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton(onPressed: () {}, child: const Text('حفظ')),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () {}, child: const Text('إلغاء')),
              const SizedBox(width: 8),
              const Chip(label: Text('ممتاز')),
            ]),
            const SizedBox(height: 10),
            const TextField(decoration: InputDecoration(labelText: 'اسم الطالب')),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: .65, color: cs.primary),
          ]),
        ),
      ),

      // ---------- الوضع ----------
      _title(context, 'وضع التطبيق'),
      SegmentedButton<ThemeMode>(
        segments: const [
          ButtonSegment(value: ThemeMode.dark, label: Text('داكن'), icon: Icon(Icons.dark_mode)),
          ButtonSegment(value: ThemeMode.light, label: Text('فاتح'), icon: Icon(Icons.light_mode)),
          ButtonSegment(value: ThemeMode.system, label: Text('النظام'), icon: Icon(Icons.phone_android)),
        ],
        selected: {mode},
        onSelectionChanged: (s) => AppState.setThemeMode(s.first),
      ),

      // ---------- اللون ----------
      _title(context, 'لون التطبيق', 'يلوّن الأزرار والتبويبات والعناصر المحددة'),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final c in _accents)
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => _set(look.copyWith(accent: c)),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                    color: look.accent.toARGB32() == c.toARGB32() ? cs.onSurface : Colors.transparent,
                    width: 3),
              ),
              child: look.accent.toARGB32() == c.toARGB32()
                  ? const Icon(Icons.check, color: Colors.white)
                  : null,
            ),
          ),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _customColor(context),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: cs.outline),
              gradient: const SweepGradient(colors: [
                Colors.red, Colors.orange, Colors.yellow, Colors.green,
                Colors.blue, Colors.purple, Colors.red,
              ]),
            ),
            child: const Icon(Icons.colorize, color: Colors.white, size: 20),
          ),
        ),
      ]),

      // ---------- الخلفية ----------
      _title(context, 'نمط الخلفية'),
      Text('الوضع الداكن', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < darkPalettes.length; i++)
          ChoiceChip(
            avatar: CircleAvatar(backgroundColor: darkPalettes[i].$2.surface, radius: 8),
            label: Text(darkPalettes[i].$1),
            selected: look.darkBg == i,
            onSelected: (_) => _set(look.copyWith(darkBg: i)),
          ),
      ]),
      const SizedBox(height: 10),
      Text('الوضع الفاتح', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      Wrap(spacing: 8, children: [
        for (var i = 0; i < lightPalettes.length; i++)
          ChoiceChip(
            avatar: CircleAvatar(
                backgroundColor: lightPalettes[i].$2.bg,
                radius: 8,
                child: Container(
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26)))),
            label: Text(lightPalettes[i].$1),
            selected: look.lightBg == i,
            onSelected: (_) => _set(look.copyWith(lightBg: i)),
          ),
      ]),

      // ---------- الأشكال ----------
      _title(context, 'أشكال الواجهة'),
      Row(children: [
        const Text('استدارة الزوايا'),
        Expanded(
          child: Slider(
            value: look.radius,
            min: 0,
            max: 32,
            divisions: 16,
            label: look.radius.round().toString(),
            onChanged: (v) => _set(look.copyWith(radius: v), save: false),
            onChangeEnd: (v) => _set(look.copyWith(radius: v)),
          ),
        ),
        Text(look.radius.round().toString()),
      ]),
      const SizedBox(height: 4),
      Text('شكل البطاقات', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('بإطار')),
          ButtonSegment(value: 1, label: Text('بظل')),
          ButtonSegment(value: 2, label: Text('ممتلئة')),
        ],
        selected: {look.cardStyle},
        onSelectionChanged: (s) => _set(look.copyWith(cardStyle: s.first)),
      ),
      const SizedBox(height: 12),
      Text('حقول الإدخال', style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 6),
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('ممتلئة')),
          ButtonSegment(value: true, label: Text('بإطار')),
        ],
        selected: {look.outlinedInputs},
        onSelectionChanged: (s) => _set(look.copyWith(outlinedInputs: s.first)),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('عرض مضغوط'),
        subtitle: const Text('يقلّل المسافات لعرض بيانات أكثر في الشاشة'),
        value: look.compact,
        onChanged: (v) => _set(look.copyWith(compact: v)),
      ),

      // ---------- الخطوط ----------
      _title(context, 'الخطوط', 'الخطوط الثقيلة (للعناوين) تناسب العناوين أكثر من النصوص الطويلة'),
      Pick<String>(
        label: 'خط النص',
        value: font,
        items: fontItems,
        onChanged: (v) => AppState.setFont(v!),
      ),
      const SizedBox(height: 10),
      Pick<String>(
        label: 'خط العناوين',
        value: look.titleFont == 'same' ? 'same' : fontById(look.titleFont).id,
        items: [
          const DropdownMenuItem(value: 'same', child: Text('مثل خط النص')),
          ...fontItems,
        ],
        onChanged: (v) => _set(look.copyWith(titleFont: v!)),
      ),
      const SizedBox(height: 10),
      Row(children: [
        const Text('حجم الخط'),
        Expanded(
          child: Slider(
            value: look.scale,
            min: 0.8,
            max: 1.4,
            divisions: 12,
            label: '${(look.scale * 100).round()}%',
            onChanged: (v) => _set(look.copyWith(scale: v), save: false),
            onChangeEnd: (v) => _set(look.copyWith(scale: v)),
          ),
        ),
        Text('${(look.scale * 100).round()}%'),
      ]),
      if (dark) const SizedBox(height: 0),
    ]);
  }
}
