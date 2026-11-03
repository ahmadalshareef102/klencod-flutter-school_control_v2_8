import 'package:flutter/material.dart';
import 'app_state.dart';
import 'fonts.dart';
import 'shell.dart';

const navy = Color(0xFF102A43);
const blue = Color(0xFF1976D2);
const pageBg = Color(0xFFF5F7FB);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.load();
  runApp(const ControlApp());
}

class Pal {
  final Color bg, surface, border, input, nav;
  const Pal(this.bg, this.surface, this.border, this.input, this.nav);
}

const darkPalettes = <(String, Pal)>[
  ('كحلي', Pal(Color(0xFF0B1220), Color(0xFF162033), Color(0xFF24324A), Color(0xFF1E2A40), Color(0xFF111A2C))),
  ('أسود', Pal(Color(0xFF000000), Color(0xFF0E0E10), Color(0xFF222226), Color(0xFF1A1A1E), Color(0xFF000000))),
  ('رمادي', Pal(Color(0xFF16181D), Color(0xFF22252C), Color(0xFF343842), Color(0xFF2B2F37), Color(0xFF1B1D23))),
  ('أخضر داكن', Pal(Color(0xFF0B1512), Color(0xFF14231D), Color(0xFF22382F), Color(0xFF1B2E26), Color(0xFF0F1B16))),
];
const lightPalettes = <(String, Pal)>[
  ('أزرق فاتح', Pal(Color(0xFFF5F7FB), Color(0xFFFFFFFF), Color(0xFFE3EAF2), Color(0xFFEFF3F9), Color(0xFFFFFFFF))),
  ('كريمي', Pal(Color(0xFFFBF7EE), Color(0xFFFFFFFF), Color(0xFFEADFC8), Color(0xFFF5EEDC), Color(0xFFFFFDF8))),
  ('أبيض', Pal(Color(0xFFFFFFFF), Color(0xFFFAFAFA), Color(0xFFE5E5E5), Color(0xFFF0F0F0), Color(0xFFFFFFFF))),
  ('نعناعي', Pal(Color(0xFFF1F8F4), Color(0xFFFFFFFF), Color(0xFFD6E8DD), Color(0xFFE6F2EB), Color(0xFFFFFFFF))),
];

ThemeData buildTheme(Brightness b, String fontId, LookPrefs look) {
  final dark = b == Brightness.dark;
  final pal = (dark ? darkPalettes : lightPalettes)[dark ? look.darkBg : look.lightBg].$2;
  final cs = ColorScheme.fromSeed(seedColor: look.accent, brightness: b);
  final r = look.radius;
  final br = BorderRadius.circular(r);
  final ir = r.clamp(0, 28).toDouble();
  final btnShape = r >= 26
      ? const StadiumBorder()
      : RoundedRectangleBorder(borderRadius: BorderRadius.circular(r * 0.8));

  final body = fontById(fontId);
  final head = look.titleFont == 'same' ? body : fontById(look.titleFont);
  final base = ThemeData(brightness: b, useMaterial3: true).textTheme;
  final bt = base.apply(fontFamily: body.family, fontSizeFactor: body.adjust);
  final ht = base.apply(fontFamily: head.family, fontSizeFactor: head.adjust);
  final tt = bt.copyWith(
    displayLarge: ht.displayLarge, displayMedium: ht.displayMedium,
    displaySmall: ht.displaySmall, headlineLarge: ht.headlineLarge,
    headlineMedium: ht.headlineMedium, headlineSmall: ht.headlineSmall,
    titleLarge: ht.titleLarge, titleMedium: ht.titleMedium,
    titleSmall: ht.titleSmall,
  );

  final inputBorder = look.outlinedInputs
      ? OutlineInputBorder(
          borderRadius: BorderRadius.circular(ir),
          borderSide: BorderSide(color: pal.border))
      : OutlineInputBorder(
          borderRadius: BorderRadius.circular(ir),
          borderSide: BorderSide.none);

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    textTheme: tt,
    visualDensity: look.compact ? VisualDensity.compact : VisualDensity.standard,
    scaffoldBackgroundColor: pal.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: pal.bg,
      foregroundColor: dark ? Colors.white : navy,
      elevation: 0,
      titleTextStyle: tt.titleLarge?.copyWith(color: dark ? Colors.white : navy),
    ),
    cardTheme: CardThemeData(
      color: look.cardStyle == 2 ? pal.input : pal.surface,
      elevation: look.cardStyle == 1 ? 4 : 0,
      shadowColor: Colors.black,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: br,
        side: look.cardStyle == 0 ? BorderSide(color: pal.border) : BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: !look.outlinedInputs,
      fillColor: pal.input,
      border: inputBorder,
      enabledBorder: inputBorder,
      focusedBorder: inputBorder.copyWith(borderSide: BorderSide(color: cs.primary, width: 1.6)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: btnShape)),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(shape: btnShape)),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(shape: btnShape)),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r * 0.6)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: pal.nav,
      indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
      labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontFamily: body.family, fontSize: 11 * body.adjust, color: cs.onSurface)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: pal.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r + 4)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: pal.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(r + 4))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r * 0.7)),
    ),
  );
}

class ControlApp extends StatelessWidget {
  const ControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.font, AppState.themeMode, AppState.look]),
      builder: (context, _) {
        final font = AppState.font.value;
        final look = AppState.look.value;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'الكنترول المدرسي',
          themeMode: AppState.themeMode.value,
          theme: buildTheme(Brightness.light, font, look),
          darkTheme: buildTheme(Brightness.dark, font, look),
          builder: (context, child) {
            final base = MediaQuery.textScalerOf(context).scale(1.0);
            return MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(base * look.scale)),
              child: Directionality(
                  textDirection: TextDirection.rtl, child: child ?? const SizedBox()),
            );
          },
          home: const Shell(),
        );
      },
    );
  }
}