import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quire/theme/colors.dart';
import 'quire/theme/typography.dart';

ThemeData buildTheme(Palette p) {
  final dark = p.brightness == Brightness.dark;
  final scheme = (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
    primary: p.accent,
    onPrimary: p.onAccent,
    primaryContainer: p.accentMuted,
    onPrimaryContainer: p.ink,
    secondary: p.accentBright,
    onSecondary: p.onAccentBright,
    secondaryContainer: p.accentMuted,
    onSecondaryContainer: p.ink,
    tertiary: p.accentPale,
    error: p.damage,
    surface: p.surface,
    onSurface: p.ink,
    surfaceContainerLowest: p.ground,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHigh,
    onSurfaceVariant: p.inkSoft,
    outline: p.hairline,
    outlineVariant: p.hairline,
    inverseSurface: p.ink,
    onInverseSurface: p.ground,
    scrim: p.scrim,
    shadow: Colors.transparent,
    surfaceTint: Colors.transparent,
  );
  return ThemeData(
    brightness: p.brightness,
    colorScheme: scheme,
    fontFamily: kFontFamily,
    scaffoldBackgroundColor: p.ground,
    canvasColor: p.ground,
    dividerColor: p.hairline,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    iconTheme: IconThemeData(color: p.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: p.ground,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: AppText.title.copyWith(color: p.ink),
      systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
    ),
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: AppText.search.copyWith(color: p.inkSoft),
      floatingLabelStyle: AppText.label.copyWith(color: p.accentBright),
      hintStyle: AppText.search.copyWith(color: p.inkFaint),
      helperStyle: AppText.docMeta.copyWith(color: p.inkSoft),
      errorStyle: AppText.docMeta.copyWith(color: p.damage),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.hairline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.inkFaint.withValues(alpha: 0.6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.accentBright, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.damage),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: p.damage, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: p.accentBright,
      selectionColor: AppColors.foundWash,
      selectionHandleColor: p.accentBright,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onAccent : p.inkFaint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.accent : p.surfaceHigh),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.surfaceHigh,
      contentTextStyle: AppText.label.copyWith(color: p.ink),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
