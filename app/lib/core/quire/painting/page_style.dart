import 'package:flutter/painting.dart';

import '../model/document.dart';

// Quire's page, as its reader and its desk thumbnails set it: the measures, ink and type of lib/theme and of the
// reader's prose and sheet bodies, copied at their own values so a preview here is the page Quire draws.

const kScreenWidth = 402.0;
const kSheetWidth = kScreenWidth;
const kThumbnailAspect = 1 / 1.15;
const kSheetPadding = 26.0;
const kProseMeasure = kSheetWidth - 2 * kSheetPadding;
const kSpace4 = 4.0;
const kSpace8 = 8.0;
const kSpace12 = 12.0;
const kCodeRadius = 6.0;
const kRowHeaderWidth = 40.0;
const kSpineWidth = 12.0;
const kSpineWidthMax = 28.0;
const kOpenColumnMin = 160.0;
const kOpenColumnMax = 272.0;
const kTableHeaderHeight = 32.0;
const kTableRowHeight = 30.0;
const kCellPaddingX = 8.0;
const kSpineBarMax = 10.0;
const kSpineBarHeight = 2.0;
const kSpineDot = 4.0;

const double kProseIndent = 22.0;
const double kProseMarkerGutter = 18.0;
const double kProseBullet = 4.0;
const double kProseQuoteBar = 3.0;
const double kProseQuoteInset = 14.0;
const double kProseRuleFraction = 0.4;
const double kProseImageMaxHeight = 320.0;
const double kProseMissingImageHeight = 160.0;
const double kProseTableScale = 0.9;

abstract final class PageColors {
  static const page = Color(0xFFFFFFFF);
  static const pageInk = Color(0xFF111111);
  static final pageInkSoft = Color.lerp(page, pageInk, 0.45)!;
}

const kFontFamily = 'Inter';

TextStyle _text({
  required double size,
  required double lineHeight,
  FontWeight weight = FontWeight.w400,
  double letterSpacing = 0,
  bool tabular = false,
}) {
  return TextStyle(
    inherit: false,
    fontFamily: kFontFamily,
    fontSize: size,
    height: lineHeight / size,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
  );
}

abstract final class PageText {
  static final pageHeading1 = _text(size: 24, lineHeight: 30, weight: FontWeight.w700, letterSpacing: -0.4);
  static final pageHeading2 = _text(size: 19, lineHeight: 25, weight: FontWeight.w600, letterSpacing: -0.2);
  static final pageHeading3 = _text(size: 16, lineHeight: 21, weight: FontWeight.w600);
  static final pageBody = _text(size: 15.5, lineHeight: 24);
  static final code = _text(size: 13.5, lineHeight: 20, weight: FontWeight.w500, letterSpacing: 0.1, tabular: true);
  static final cell = _text(size: 13, lineHeight: 17, tabular: true);
  static final cellHeader = _text(size: 12, lineHeight: 15, weight: FontWeight.w600, letterSpacing: 0.4);
  static final folio = _text(size: 12, lineHeight: 15, weight: FontWeight.w500, letterSpacing: 1.2, tabular: true);
  static final folioSmall = _text(size: 10, lineHeight: 13, weight: FontWeight.w500, letterSpacing: 1.0, tabular: true);
}

TextStyle proseHeadingStyle(HeadingBlock block) => switch (block.level) {
  1 => PageText.pageHeading1,
  2 => PageText.pageHeading2,
  _ => PageText.pageHeading3,
};

double proseSpaceAbove(DocBlock block) => switch (block) {
  HeadingBlock(:final level) when level == 1 => 28,
  HeadingBlock(:final level) when level == 2 => 24,
  HeadingBlock() => 20,
  DividerBlock() => 24,
  ImageBlock() => 20,
  TableBlock() => 16,
  CodeBlock() => 12,
  _ => 0,
};

double proseSpaceBelow(DocBlock block) => switch (block) {
  HeadingBlock(:final level) when level == 1 => 10,
  HeadingBlock(:final level) when level == 2 => 8,
  HeadingBlock() => 6,
  DividerBlock() => 24,
  ImageBlock() => 20,
  TableBlock() => 16,
  CodeBlock() => 12,
  ListItemBlock() => 6,
  _ => 12,
};

/// The larger of what one block asks for below and the next asks for above, never the sum.
double proseGap(DocBlock above, DocBlock below) =>
    proseSpaceBelow(above) > proseSpaceAbove(below) ? proseSpaceBelow(above) : proseSpaceAbove(below);

/// Markdown wraps its source wherever the writer liked, so each of its line breaks is a space.
String foldLineBreak(String text) => text.replaceAll(_lineBreak, ' ');

final RegExp _lineBreak = RegExp('[ \t]*\r?\n[ \t]*');

enum SpineMark { none, bar, dot }

/// A folded cell: a bar as long as its number is against the column's largest, a dot for anything else.
class SpineValue {
  const SpineValue(this.mark, {this.extent = 0});
  final SpineMark mark;
  final double extent;
}

double spineBarWidth(double extent) => (kSpineBarMax * extent).clamp(1.0, kSpineBarMax);

({double open, double spine}) columnWidths(int columns) {
  final spines = columns - 1;
  const avail = kSheetWidth - kRowHeaderWidth;
  if (spines <= 0) return (open: avail, spine: 0);
  var spine = kSpineWidth;
  var open = avail - spines * spine;
  if (open > kOpenColumnMax) {
    spine = ((avail - kOpenColumnMax) / spines).clamp(kSpineWidth, kSpineWidthMax);
    open = avail - spines * spine;
  }
  return (open: open.clamp(kOpenColumnMin, avail), spine: spine);
}

List<double> spineWidths(int columns, {required int open}) {
  final widths = columnWidths(columns);
  return <double>[for (var c = 0; c < columns; c++) c == open ? widths.open : widths.spine];
}

String columnLetter(int index) {
  var n = index;
  final letters = <int>[];
  while (true) {
    letters.add(0x41 + n % 26);
    n = n ~/ 26 - 1;
    if (n < 0) break;
  }
  return String.fromCharCodes(letters.reversed);
}

final RegExp _whitespace = RegExp(r'\s+');

String flattenCell(String text) => text.isEmpty ? text : text.replaceAll(_whitespace, ' ').trim();

DocCell? cellAt(TableBlock table, int row, int column) {
  if (row < 0 || row >= table.rows.length) return null;
  final cells = table.rows[row].cells;
  if (column < 0 || column >= cells.length) return null;
  return cells[column];
}

List<SpineValue> spineValuesFor(TableBlock table, int column, {int from = 0}) {
  var largest = 0.0;
  for (var r = from; r < table.rows.length; r++) {
    final raw = cellAt(table, r, column)?.raw;
    if (raw is num && raw.abs() > largest) largest = raw.abs().toDouble();
  }
  return <SpineValue>[
    for (var r = from; r < table.rows.length; r++)
      switch (cellAt(table, r, column)) {
        null => const SpineValue(SpineMark.none),
        final cell when cell.merged || cell.text.trim().isEmpty => const SpineValue(SpineMark.none),
        final cell when cell.raw is num && largest > 0 => SpineValue(SpineMark.bar, extent: (cell.raw as num).abs().toDouble() / largest),
        _ => const SpineValue(SpineMark.dot),
      },
  ];
}
