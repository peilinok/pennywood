import 'package:flutter/material.dart';

final paperThemeMode = ValueNotifier<ThemeMode>(ThemeMode.system);

// Share semantic colors with design system 0.3; illustrations retain their asset colors.
class PaperColors {
  PaperColors(this.dark);
  final bool dark;
  static PaperColors of(BuildContext context) =>
      PaperColors(Theme.of(context).brightness == Brightness.dark);
  Color get paper => Color(dark ? 0xFF242620 : 0xFFF8F7F2);
  Color get surface => Color(dark ? 0xFF2D3029 : 0xFFFFFEFA);
  Color get soft => Color(dark ? 0xFF35382F : 0xFFEEEDE5);
  Color get ink => Color(dark ? 0xFFF1EFE3 : 0xFF302D27);
  Color get muted => Color(dark ? 0xFFC1BFB1 : 0xFF686357);
  Color get line => Color(dark ? 0xFF505349 : 0xFFDCD9CE);
  Color get control => Color(dark ? 0xFF989B8D : 0xFF858171);
  Color get brand => Color(dark ? 0xFFDFB587 : 0xFF7C472E);
  Color get onBrand => Color(dark ? 0xFF30251D : 0xFFFFFEFA);
  Color get green => Color(dark ? 0xFFB5C8A0 : 0xFF3F6748);
  Color get greenSoft => Color(dark ? 0xFF2E392C : 0xFFE8EDDF);
  Color get accent => Color(dark ? 0xFFE6BE63 : 0xFFE2B95B);
  Color get onAccent => Color(dark ? 0xFF30271A : 0xFF3F301B);
  Color get accentSoft => Color(dark ? 0xFF413A28 : 0xFFF3E9CF);
  Color get danger => Color(dark ? 0xFFF0B4A2 : 0xFF933F32);
  Color get night => Color(dark ? 0xFF202F34 : 0xFF2B4349);
  Color get ground => Color(dark ? 0xFF384A3D : 0xFF4C6253);
}

ThemeData paperTheme(Brightness brightness) {
  final p = PaperColors(brightness == Brightness.dark);
  final scheme =
      ColorScheme.fromSeed(seedColor: p.brand, brightness: brightness).copyWith(
        primary: p.brand,
        onPrimary: p.onBrand,
        surface: p.surface,
        onSurface: p.ink,
        onSurfaceVariant: p.muted,
        outline: p.control,
        secondary: p.green,
        secondaryContainer: p.greenSoft,
        onSecondaryContainer: p.green,
        error: p.danger,
      );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.paper,
    textTheme: ThemeData(brightness: brightness).textTheme
        .apply(bodyColor: p.ink, displayColor: p.ink)
        .copyWith(
          bodyMedium: TextStyle(fontSize: 16, height: 1.5, color: p.ink),
          bodySmall: TextStyle(fontSize: 13, height: 1.5, color: p.muted),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(44, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.control),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.green,
      linearTrackColor: p.soft,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.greenSoft,
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
