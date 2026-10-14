import 'dart:ui';

class Palette {
  const Palette({
    required this.brightness,
    required this.ground,
    required this.surface,
    required this.surfaceHigh,
    required this.hairline,
    required this.scrim,
    required this.accent,
    required this.accentBright,
    required this.accentMuted,
    required this.accentPale,
    required this.onAccent,
    required this.onAccentBright,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.damage,
  });

  final Brightness brightness;
  final Color ground;
  final Color surface;
  final Color surfaceHigh;
  final Color hairline;
  final Color scrim;
  final Color accent;
  final Color accentBright;
  final Color accentMuted;
  final Color accentPale;
  final Color onAccent;
  final Color onAccentBright;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color damage;
}

abstract final class AppColors {
  static const dark = Palette(
    brightness: Brightness.dark,
    ground: Color(0xFF131316),
    surface: Color(0xFF1E1E22),
    surfaceHigh: Color(0xFF2B2930),
    hairline: Color(0xFF2F2F35),
    scrim: Color(0x8C000000),
    accent: Color(0xFF4F378B),
    accentBright: Color(0xFFD0BCFF),
    accentMuted: Color(0xFF4A4458),
    accentPale: Color(0xFFE8DEF8),
    onAccent: Color(0xFFFFFFFF),
    onAccentBright: Color(0xFF1D192B),
    ink: Color(0xFFE6E1E5),
    inkSoft: Color(0xFFCAC4D0),
    inkFaint: Color(0xFF938F99),
    damage: Color(0xFFF2B8B5),
  );

  static const light = Palette(
    brightness: Brightness.light,
    ground: Color(0xFFFDFBFF),
    surface: Color(0xFFF3EFF7),
    surfaceHigh: Color(0xFFE9E3F0),
    hairline: Color(0xFFE2DDE6),
    scrim: Color(0x52000000),
    accent: Color(0xFF6750A4),
    accentBright: Color(0xFF4F378B),
    accentMuted: Color(0xFFE8DEF8),
    accentPale: Color(0xFFE8DEF8),
    onAccent: Color(0xFFFFFFFF),
    onAccentBright: Color(0xFFFFFFFF),
    ink: Color(0xFF1C1B1F),
    inkSoft: Color(0xFF49454F),
    inkFaint: Color(0xFF79747E),
    damage: Color(0xFFB3261E),
  );

  static Palette current = dark;

  static Color get ground => current.ground;
  static Color get surface => current.surface;
  static Color get surfaceHigh => current.surfaceHigh;
  static Color get hairline => current.hairline;
  static Color get hairlineFaint => current.hairline.withValues(alpha: 0.55);
  static Color get scrim => current.scrim;
  static Color get accent => current.accent;
  static Color get accentBright => current.accentBright;
  static Color get accentMuted => current.accentMuted;
  static Color get accentPale => current.accentPale;
  static Color get accentWash => current.accent.withValues(alpha: 0.4);
  static Color get onAccent => current.onAccent;
  static Color get onAccentBright => current.onAccentBright;
  static Color get ink => current.ink;
  static Color get inkSoft => current.inkSoft;
  static Color get inkFaint => current.inkFaint;
  static Color get damage => current.damage;
  static Color get damageTint => Color.lerp(current.surface, current.damage, 0.14)!;
  static const found = Color(0xFFF5C518);
  static const foundWash = Color(0x4FF5C518);
  static const avatar = Color(0xFF3B6B45);

  static const labelColors = [
    Color(0xFF4285F4),
    Color(0xFF21A366),
    Color(0xFFF5C518),
    Color(0xFFE8544A),
    Color(0xFFB39DDB),
    Color(0xFFC9832B),
    Color(0xFF4F378B),
    Color(0xFF938F99),
  ];
}
