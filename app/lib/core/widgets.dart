import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'quire/painting/tab_goo_painter.dart';
import 'quire/constants/gooey_fab.dart' show kGooAlphaThresholdMatrix, kGooBlurSigma;
import 'quire/theme/colors.dart';
import 'quire/theme/easings.dart';
import 'quire/theme/feedback.dart';
import 'quire/theme/metrics.dart';
import 'quire/theme/typography.dart';
import 'quire/widgets/press_fade.dart';
import 'quire/widgets/quire_spinner.dart';

import 'dart:ui' as ui;

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = true,
    this.busy = false,
    this.feel = Feel.tap,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool filled;
  final bool busy;
  final Feel feel;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.onAccent : AppColors.ink;
    return PaperPress(
      onTap: busy ? null : onTap,
      enabled: onTap != null && !busy,
      feel: feel,
      semanticLabel: label,
      washRadius: kPillRadius,
      child: AnimatedOpacity(
        duration: kDim,
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: expand ? 52 : 44,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            color: filled ? AppColors.accent : AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(kPillRadius),
          ),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy) QuireSpinner(size: 20, color: fg) else if (icon != null) Icon(icon, size: 18, color: fg),
              if (busy || icon != null) const SizedBox(width: 8),
              Text(label, style: AppText.actionPill.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class IconPress extends StatelessWidget {
  const IconPress({super.key, required this.icon, required this.onTap, required this.label, this.color, this.size = 22});
  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => PaperPress(
    onTap: onTap,
    enabled: onTap != null,
    semanticLabel: label,
    washRadius: 20,
    child: SizedBox.square(
      dimension: 44,
      child: Icon(icon, size: size, color: color ?? AppColors.ink),
    ),
  );
}

/// Quire's empty desk: the mark, a headline, one line of why, and one way forward.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.action, this.onAction, this.icon});
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(kSpace32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 56, color: AppColors.inkFaint)
          else
            Image.asset('assets/brand/quire-mark.png', width: 96, height: 96, filterQuality: FilterQuality.medium),
          const SizedBox(height: kSpace14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppText.display.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 280,
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: AppText.bodyTight.copyWith(color: AppColors.inkSoft),
            ),
          ),
          if (action != null) ...[const SizedBox(height: kSpace16), PillButton(label: action!, onTap: onAction)],
        ],
      ),
    ),
  ).animate();
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) =>
      EmptyState(icon: LucideIcons.cloudOff, title: 'Something went wrong', body: '$error', action: 'Try again', onAction: onRetry);
}

class Loader extends StatelessWidget {
  const Loader({super.key});

  @override
  Widget build(BuildContext context) => const Center(child: QuireSpinner());
}

extension _StateCardIn on Widget {
  Widget animate() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: kStateCardIn,
    curve: easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child),
    ),
    child: this,
  );
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.size = 40});
  final String name;
  final double size;

  static Color colorFor(String seed) => AppColors.labelColors[seed.hashCode.abs() % AppColors.labelColors.length];

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colorFor(name.toLowerCase()), shape: BoxShape.circle),
      child: Text(
        letter,
        style: AppText.avatar.copyWith(color: Colors.white, fontSize: size * 0.42),
      ),
    );
  }
}

/// Quire's toast: a pill that rises, with a bar draining under it while it stays.
void showToast(BuildContext context, String message, {String? action, VoidCallback? onAction}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(message: message, action: action, onAction: onAction, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({required this.message, this.action, this.onAction, required this.onDone});
  final String message;
  final String? action;
  final VoidCallback? onAction;
  final VoidCallback onDone;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with TickerProviderStateMixin {
  late final _rise = AnimationController(vsync: this, duration: kStateCardIn)..forward();
  late final _drain = AnimationController(vsync: this, duration: kUndoPill)..forward().whenComplete(_close);
  bool _closing = false;

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await _rise.reverse();
    widget.onDone();
  }

  @override
  void dispose() {
    _rise.dispose();
    _drain.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned(
    left: 16,
    right: 16,
    bottom: MediaQuery.paddingOf(context).bottom + 88,
    child: AnimatedBuilder(
      animation: Listenable.merge([_rise, _drain]),
      builder: (context, child) {
        final t = easeOutCubic.transform(_rise.value);
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - t)),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(widget.message, style: AppText.label.copyWith(color: AppColors.ink)),
                            ),
                          ),
                          if (widget.action != null)
                            PaperPress(
                              feel: Feel.commit,
                              onTap: () {
                                widget.onAction?.call();
                                _close();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Text(widget.action!.toUpperCase(), style: AppText.label.copyWith(color: AppColors.accentBright)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 1 - _drain.value,
                        child: Container(height: 2, color: AppColors.accentBright),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Quire's desk sheet: rises from the bottom over a scrim.
Future<T?> showQuireSheet<T>(BuildContext context, WidgetBuilder builder) => Navigator.of(context).push<T>(
  PageRouteBuilder<T>(
    opaque: false,
    barrierColor: AppColors.scrim,
    barrierDismissible: true,
    barrierLabel: 'Close',
    transitionDuration: kPadArrival,
    reverseTransitionDuration: kPadArrival,
    pageBuilder: (context, animation, secondary) => Align(
      alignment: Alignment.bottomCenter,
      child: Material(
        color: AppColors.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(color: AppColors.hairline, borderRadius: BorderRadius.circular(2)),
                ),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      ),
    ),
    transitionsBuilder: (context, animation, secondary, child) => SlideTransition(
      position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: easeOutCubic)),
      child: child,
    ),
  ),
);

class SheetRow extends StatelessWidget {
  const SheetRow({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.destructive = false,
    this.trailing,
    this.selected = false,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool destructive;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? AppColors.damage : AppColors.ink;
    return PaperPress(
      onTap: onTap,
      enabled: onTap != null,
      feel: destructive ? Feel.commit : Feel.tap,
      semanticLabel: label,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: selected ? AppColors.accentMuted : null,
        child: Row(
          children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 16)],
            Expanded(
              child: Text(label, style: AppText.menuRow.copyWith(color: color)),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class SheetTitle extends StatelessWidget {
  const SheetTitle(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: AppText.title.copyWith(color: AppColors.ink)),
    ),
  );
}

/// A text prompt in a sheet, Quire's replacement for dialogs. Pops with the trimmed text.
Future<String?> promptText(BuildContext context, {required String title, String initial = '', String action = 'Save', String? hint}) =>
    showQuireSheet<String>(context, (context) {
      final controller = TextEditingController(text: initial);
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: AppText.title.copyWith(color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(hintText: hint),
              onSubmitted: (v) => Navigator.pop(context, v.trim()),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: PillButton(label: action, onTap: () => Navigator.pop(context, controller.text.trim())),
            ),
          ],
        ),
      );
    });

Future<bool> confirm(BuildContext context, {required String title, required String action, String? body}) async =>
    await showQuireSheet<bool>(
      context,
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SheetTitle(title),
          if (body != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(body, style: AppText.bodyTight.copyWith(color: AppColors.inkSoft)),
            ),
          SheetRow(label: action, icon: LucideIcons.trash2, destructive: true, onTap: () => Navigator.pop(context, true)),
          SheetRow(label: 'Cancel', icon: LucideIcons.x, onTap: () => Navigator.pop(context, false)),
        ],
      ),
    ) ??
    false;

/// Equal-width segments with Quire's tab goo: the selection travels as a blob between pills.
class GooSegmented<T> extends StatefulWidget {
  const GooSegmented({super.key, required this.values, required this.labels, required this.selected, required this.onChanged});
  final List<T> values;
  final List<String> labels;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  State<GooSegmented<T>> createState() => _GooSegmentedState<T>();
}

class _GooSegmentedState<T> extends State<GooSegmented<T>> with SingleTickerProviderStateMixin {
  late final _travel = AnimationController(vsync: this, duration: kTabTravel, value: 1);
  late int _from = widget.values.indexOf(widget.selected);

  @override
  void didUpdateWidget(GooSegmented<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      _from = old.values.indexOf(old.selected);
      _travel.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const height = 36.0;
      const pad = 3.0;
      final w = (box.maxWidth - pad * 2) / widget.values.length;
      Rect rect(int i) => Rect.fromLTWH(pad + i * w, pad, w, height - pad * 2);
      final to = widget.values.indexOf(widget.selected);
      return Container(
        height: height,
        decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(height / 2)),
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _travel,
                builder: (context, _) => ClipRect(
                  child: ColorFiltered(
                    colorFilter: const ColorFilter.matrix(kGooAlphaThresholdMatrix),
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(sigmaX: kGooBlurSigma / 3, sigmaY: kGooBlurSigma / 3, tileMode: TileMode.decal),
                      child: CustomPaint(
                        painter: TabGooPainter(from: rect(_from), to: rect(to), t: _travel.value, colour: AppColors.accentMuted),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < widget.values.length; i++)
                  Expanded(
                    child: PaperPress(
                      washRadius: height / 2,
                      semanticLabel: widget.labels[i],
                      onTap: () => widget.onChanged(widget.values[i]),
                      child: Center(
                        child: Text(widget.labels[i], style: AppText.label.copyWith(color: i == to ? AppColors.ink : AppColors.inkSoft)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Color parseHex(String? hex, Color fallback) {
  if (hex == null || !hex.startsWith('#') || hex.length != 7) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}

String toHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// A borderless field for inline rows (recipients, subject, search) that should read as text, not as a form box.
InputDecoration bareInput({String? hint, TextStyle? hintStyle, EdgeInsets padding = const EdgeInsets.symmetric(vertical: 14)}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: hintStyle,
      isDense: true,
      filled: false,
      contentPadding: padding,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    );
