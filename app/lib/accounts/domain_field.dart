import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/quire/constants/gooey_fab.dart';
import '../core/quire/painting/cell_goo_painter.dart';
import '../core/quire/theme/colors.dart';
import '../core/quire/theme/feedback.dart';
import '../core/quire/theme/springs.dart';
import '../core/quire/theme/typography.dart';
import '../core/quire/widgets/press_fade.dart';

const _drop = 26.0;
const _chipHeight = 36.0;
const _rowHeight = _chipHeight + 14;

/// The chip's words are gone before its fill starts to draw in, so nothing hangs off the goo as it gathers.
const _labelFade = Duration(milliseconds: 50);

/// How far the chip has drawn in, as a multiple of a drop, when it sets off. It leaps while still gathering, so the
/// draw-in reads as a crouch before the leap rather than a pause.
const _leapAt = 4.0;

// Quire's sheet springs are tuned for crossing a screen of cells; this hop is a thumb's width, so it is quicker.
// It rises faster than it slides, so the drop arcs up into the line and runs along it.
final _gather = SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 1);
final _rise = SpringDescription.withDampingRatio(mass: 1, stiffness: 240, ratio: 0.78);
final _slide = SpringDescription.withDampingRatio(mass: 1, stiffness: 150, ratio: 0.86);
final _trail = SpringDescription.withDampingRatio(mass: 1, stiffness: 80, ratio: 1);

/// The suggested @domain as goo, moved the way Quire's spreadsheet moves its choice between cells: it gathers into a
/// drop, crosses with a neck drawn back to where it left, and spreads into the slot it lands in.
class _Goo {
  final _headX = SpringValue(0);
  final _headY = SpringValue(0);
  final _tailX = SpringValue(0);
  final _tailY = SpringValue(0);
  final _width = SpringValue(0);
  final _height = SpringValue(0);
  final _corner = SpringValue(0);
  final _fill = SpringValue(0, tolerance: SpringValue.shareTolerance);
  Rect? _slot;
  bool _gathering = false;
  bool _spread = false;

  List<SpringValue> get _all => [_headX, _headY, _tailX, _tailY, _width, _height, _corner, _fill];

  bool restingAt(double now) => _all.every((v) => v.restingAt(now));
  bool get shown => _fill.target > 0;
  bool get hopping => _slot != null;
  bool get pouring => _slot != null && _spread;

  /// Rests on [chip], condensing there as a drop first when no goo was showing.
  void restOn(Rect chip, double now) {
    if (!shown) {
      _jump(chip.center);
      _width.jumpTo(_drop);
      _height.jumpTo(_drop);
      _corner.jumpTo(_drop / 2);
      _fill.jumpTo(0);
    }
    _slot = null;
    _send(chip.center, now, AppSprings.gooSpread, AppSprings.gooSpread);
    _width.sendTo(chip.width, now, AppSprings.gooSpread);
    _height.sendTo(chip.height, now, AppSprings.gooSpread);
    _corner.sendTo(chip.height / 2, now, AppSprings.gooSpread);
    _fill.sendTo(1, now, AppSprings.gooRise);
  }

  /// Leaves the chip for [slot]: draws in to a drop, then leaps.
  void hop(Rect slot, double now) {
    _slot = slot;
    _gathering = true;
    _spread = false;
    final start = now + _labelFade.inMicroseconds / 1e6;
    _width.sendTo(_drop, start, _gather);
    _height.sendTo(_drop, start, _gather);
    _corner.sendTo(_drop / 2, start, _gather);
  }

  /// Draws in to a drop where it is and dries up.
  void dry(double now) {
    _slot = null;
    _width.sendTo(_drop, now, AppSprings.gooSet);
    _height.sendTo(_drop, now, AppSprings.gooSet);
    _corner.sendTo(_drop / 2, now, AppSprings.gooSet);
    _fill.sendTo(0, now, AppSprings.gooSet);
  }

  /// Leaps once gathered, lands just after the caret and pours along the slot. True once, when it has poured to the
  /// end and hands over to the text.
  bool step(double now) {
    final slot = _slot;
    if (slot == null) return false;
    final landing = Offset(slot.left + 6 + _drop / 2, slot.center.dy);
    if (_gathering) {
      if (_width.valueAt(now) > _drop * _leapAt) return false;
      _gathering = false;
      _headX.sendTo(landing.dx, now, _slide);
      _headY.sendTo(landing.dy, now, _rise);
      _tailX.sendTo(landing.dx, now, _trail);
      _tailY.sendTo(landing.dy, now, _trail);
    }
    final head = Offset(_headX.valueAt(now), _headY.valueAt(now));
    if (!_spread && (head - landing).distance < 12) {
      // Moving the middle and the width on one spring keeps the left edge at the caret, so it pours rightward.
      _spread = true;
      _send(slot.center, now, AppSprings.gooSpread, _trail);
      _width.sendTo(slot.width, now, AppSprings.gooSpread);
      _height.sendTo(slot.height, now, AppSprings.gooSpread);
      _corner.sendTo(slot.height / 2, now, AppSprings.gooSpread);
    }
    if (!_spread || _width.valueAt(now) < slot.width * 0.97) return false;
    _slot = null;
    _fill.sendTo(0, now, AppSprings.gooGiveWay);
    return true;
  }

  void _jump(Offset at) {
    for (final (value, to) in [(_headX, at.dx), (_headY, at.dy), (_tailX, at.dx), (_tailY, at.dy)]) {
      value.jumpTo(to);
    }
  }

  void _send(Offset to, double now, SpringDescription head, SpringDescription tail) {
    _headX.sendTo(to.dx, now, head);
    _headY.sendTo(to.dy, now, head);
    _tailX.sendTo(to.dx, now, tail);
    _tailY.sendTo(to.dy, now, tail);
  }

  double fillAt(double now) => _fill.valueAt(now).clamp(0.0, 1.0);

  CellGoo frameAt(double now) {
    final head = Offset(_headX.valueAt(now), _headY.valueAt(now));
    final tail = Offset(_tailX.valueAt(now), _tailY.valueAt(now));
    final w = math.max(0.0, _width.valueAt(now));
    final h = math.max(0.0, _height.valueAt(now));
    final gap = (head - tail).distance;
    const radius = _drop / 2;
    final scale = (math.min(w, h) / _drop).clamp(0.0, 1.0);
    final joined = gap < 1 || scale <= 0;
    return CellGoo(
      body: Rect.fromCenter(center: head, width: w, height: h),
      corner: math.max(0.0, _corner.valueAt(now)),
      tail: tail,
      tailRadius: joined ? 0 : radius * (0.8 - 0.3 * (gap / 160).clamp(0.0, 1.0)) * scale,
      neck: joined ? 0 : (kCellGooNeckVolume / gap).clamp(kCellGooNeckMin, radius * 0.7) * scale,
      velocity: Offset(_headX.velocityAt(now), _headY.velocityAt(now)),
    );
  }
}

/// The email field of Add account. Type your name and the server's @domain waits under the field; swipe right across
/// the field, press Tab or tap it, and it jumps in as goo and becomes the rest of the address.
class DomainField extends StatefulWidget {
  const DomainField({super.key, required this.controller, required this.domain, required this.onSubmitted, this.decoration});
  final TextEditingController controller;
  final String? domain;
  final VoidCallback onSubmitted;
  final InputDecoration? decoration;

  @override
  State<DomainField> createState() => DomainFieldState();
}

class DomainFieldState extends State<DomainField> with SingleTickerProviderStateMixin {
  final _stack = GlobalKey();
  final _field = GlobalKey();
  final _chip = GlobalKey();
  final _focus = FocusNode();
  final _goo = _Goo();
  late final Ticker _ticker = createTicker(_tick);
  double _base = 0;
  double _now = 0;
  _Line? _line;
  String? _hopping;
  bool _submitAfter = false;
  Offset? _down;
  Duration _downAt = Duration.zero;

  /// What the server's domain still adds to what is typed, or null when it adds nothing.
  String? get _rest {
    final domain = widget.domain?.toLowerCase();
    final text = widget.controller.text;
    if (domain == null || text.trim().isEmpty || text.contains(RegExp(r'\s'))) return null;
    final at = text.indexOf('@');
    if (at < 0) return '@$domain';
    final typed = text.substring(at + 1).toLowerCase();
    return at > 0 && typed.length < domain.length && domain.startsWith(typed) ? domain.substring(typed.length) : null;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focus.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.tab || _rest == null) return KeyEventResult.ignored;
      complete();
      return KeyEventResult.handled;
    };
    _sync();
  }

  @override
  void didUpdateWidget(DomainField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.domain != widget.domain) _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _ticker.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    _now = _base + elapsed.inMicroseconds / 1e6;
    if (_goo.step(_now)) _land();
    if (_goo.restingAt(_now)) {
      _ticker.stop();
      _base = _now;
    }
    setState(() {});
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  void _sync() {
    if (!mounted || _hopping != null) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _settle());
  }

  /// After layout: measures the field's line, and puts the goo on the chip or dries it up.
  void _settle() {
    if (!mounted || _hopping != null) return;
    final line = _measureLine();
    if (line != null && line != _line) setState(() => _line = line);
    if (_rest == null) {
      if (_goo.shown) {
        _goo.dry(_now);
        _wake();
      }
      return;
    }
    final chip = _rectOf(_chip);
    if (chip == null) return;
    _goo.restOn(chip, _now);
    _wake();
  }

  /// Adds the rest of the address, hopping in as goo when there is room to see it. [submit] goes on to the next step
  /// once the address is whole.
  void complete({bool submit = false}) {
    final rest = _rest;
    if (rest == null) {
      if (submit) widget.onSubmitted();
      return;
    }
    if (_hopping != null) return;
    Feel.commit.ring();
    _hopping = rest;
    _submitAfter = submit;
    final slot = _ghost(rest)?.slot;
    if (slot == null || !_goo.shown || MediaQuery.disableAnimationsOf(context)) return _land();
    _goo.hop(slot, _now);
    _wake();
    setState(() {});
  }

  void _land() {
    final rest = _hopping;
    _hopping = null;
    if (rest != null) {
      final text = widget.controller.text + rest;
      widget.controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      // A swipe across the field leaves Android's caret handle up, which reads as a stray drop of goo.
      WidgetsBinding.instance.addPostFrameCallback((_) => _editableState()?.hideToolbar());
    }
    if (_submitAfter) {
      _submitAfter = false;
      widget.onSubmitted();
    }
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize || !stack.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: stack) & box.size;
  }

  EditableTextState? _editableState() {
    EditableTextState? found;
    void visit(Element e) {
      if (e is StatefulElement && e.state is EditableTextState) found = e.state as EditableTextState;
      if (found == null) e.visitChildElements(visit);
    }

    (_field.currentContext as Element?)?.visitChildElements(visit);
    return found;
  }

  RenderEditable? _editableIn(RenderObject? node) {
    if (node is RenderEditable) return node;
    RenderEditable? found;
    node?.visitChildren((child) => found ??= _editableIn(child));
    return found;
  }

  _Line? _measureLine() {
    final editable = _editableIn(_field.currentContext?.findRenderObject());
    final stack = _stack.currentContext?.findRenderObject() as RenderBox?;
    final field = _rectOf(_field);
    if (editable == null || stack == null || field == null || !editable.hasSize) return null;
    final caret = editable.getLocalRectForCaret(const TextPosition(offset: 0));
    return _Line(
      start: editable.localToGlobal(caret.topLeft, ancestor: stack),
      height: caret.height,
      end: field.right - 14,
      style: editable.text?.style ?? AppText.search,
      scaler: editable.textScaler,
    );
  }

  /// Where the rest of the address shows faintly, and the slot the goo spreads into: from the end of what is typed,
  /// as wide as the rest will be.
  ({Offset at, double width, Rect slot})? _ghost(String rest) {
    final line = _line;
    if (line == null) return null;
    final x = line.start.dx + line.widthOf(widget.controller.text);
    final width = math.max(0.0, line.end - x);
    final right = math.min(x + line.widthOf(rest), line.end);
    if (width < 24) return null;
    return (
      at: Offset(x, line.start.dy),
      width: width,
      slot: Rect.fromLTRB(x - 6, line.start.dy - 5, right + 6, line.start.dy + line.height + 5),
    );
  }

  void _pointerUp(PointerUpEvent e) {
    final from = _down;
    _down = null;
    if (from == null) return;
    final moved = e.position - from;
    final quick = e.timeStamp - _downAt < const Duration(milliseconds: 800);
    if (quick && moved.dx > 48 && moved.dx > moved.dy.abs() * 2) complete();
  }

  Widget _gooLayer(CellGoo goo, double opacity) => Positioned.fill(
    child: IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(kGooAlphaThresholdMatrix),
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: kGooBlurSigma, sigmaY: kGooBlurSigma, tileMode: TileMode.decal),
            child: CustomPaint(
              painter: CellGooPainter(goo: goo, colour: AppColors.accentMuted),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    ),
  );

  /// True while the goo is on its way into the field, when it is drawn over the field's outline so the outline does
  /// not cut it in two. Once all of it is inside, it goes under the text.
  bool _over(CellGoo goo) {
    if (!_goo.hopping) return false;
    final inner = _rectOf(_field)?.deflate(3);
    if (inner == null) return false;
    final body = goo.body;
    final tailIn = goo.tailRadius == 0 || inner.inflate(-goo.tailRadius).contains(goo.tail);
    return !(inner.contains(body.topLeft) && inner.contains(body.bottomRight) && tailIn);
  }

  @override
  Widget build(BuildContext context) {
    final rest = _hopping ?? _rest;
    final domain = widget.domain;
    final ghost = rest == null ? null : _ghost(rest);
    final offered = _rest != null && _hopping == null;
    final goo = _goo.frameAt(_now);
    final fill = _goo.fillAt(_now);
    final over = _over(goo);
    final style = _line?.style;
    final restWidth = rest == null ? 0.0 : _line?.widthOf(rest) ?? 0.0;
    final poured = ghost == null || !_goo.pouring || restWidth == 0 ? 0.0 : ((goo.body.right - ghost.at.dx) / restWidth).clamp(0.0, 1.0);
    return Listener(
      onPointerDown: (e) {
        _down = e.position;
        _downAt = e.timeStamp;
      },
      onPointerUp: _pointerUp,
      onPointerCancel: (_) => _down = null,
      child: Stack(
        key: _stack,
        clipBehavior: Clip.none,
        children: [
          _gooLayer(goo, over ? 0 : fill),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: _field,
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => complete(submit: true),
                decoration: widget.decoration ?? const InputDecoration(labelText: 'Enter your email'),
              ),
              if (domain != null)
                ClipRect(
                  child: AnimatedAlign(
                    alignment: Alignment.topLeft,
                    heightFactor: _rest != null || _hopping != null ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutCubic,
                    child: SizedBox(
                      height: _rowHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: _rowHeight - _chipHeight),
                        child: AnimatedOpacity(
                          opacity: offered ? 1 : 0,
                          duration: offered ? const Duration(milliseconds: 160) : _labelFade,
                          child: IgnorePointer(
                            ignoring: !offered,
                            child: Row(
                              children: [
                                PaperPress(
                                  onTap: complete,
                                  feel: Feel.none,
                                  wash: false,
                                  semanticLabel: 'Add @$domain',
                                  washRadius: _chipHeight / 2,
                                  child: SizedBox(
                                    key: _chip,
                                    height: _chipHeight,
                                    child: ExcludeSemantics(
                                      child: Padding(
                                        padding: const EdgeInsets.only(left: 12, right: 14),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(LucideIcons.arrowRightToLine, size: 16, color: AppColors.ink),
                                            const SizedBox(width: 8),
                                            Text('@$domain', style: AppText.label.copyWith(color: AppColors.ink)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tap it, or swipe the field right',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.docMeta.copyWith(color: AppColors.inkSoft),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          _gooLayer(goo, over ? fill : 0),
          if (ghost != null && style != null) ...[
            Positioned(
              left: ghost.at.dx,
              top: ghost.at.dy,
              width: ghost.width,
              child: IgnorePointer(
                child: Text(
                  rest!,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.fade,
                  style: style.copyWith(color: AppColors.inkFaint),
                ),
              ),
            ),
            // The rest turns to ink behind the pour's leading edge, so the goo is seen to write it.
            if (poured > 0)
              Positioned(
                left: ghost.at.dx,
                top: ghost.at.dy,
                child: IgnorePointer(
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: poured,
                      child: Text(rest, maxLines: 1, softWrap: false, style: style.copyWith(color: AppColors.ink)),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The field's line of text, measured once it is laid out: where text starts, how tall a line is, how far text can
/// run, and the type it is set in.
class _Line {
  const _Line({required this.start, required this.height, required this.end, required this.style, required this.scaler});
  final Offset start;
  final double height;
  final double end;
  final TextStyle style;
  final TextScaler scaler;

  double widthOf(String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  bool operator ==(Object other) =>
      other is _Line &&
      other.start == start &&
      other.height == height &&
      other.end == end &&
      other.style == style &&
      other.scaler == scaler;

  @override
  int get hashCode => Object.hash(start, height, end, style, scaler);
}
