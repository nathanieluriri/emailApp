import 'dart:ui';

import 'quire_mark_data.dart';
import 'svg_path.dart';

const kMarkViewport = 240.0;

class MarkPane {
  MarkPane({required this.outline, required this.holes}) : square = _squareOf(outline);

  final Path outline;
  final List<Path> holes;

  final Rect square;

  Offset get centre => square.center;

  static Rect _squareOf(Path outline) {
    final bounds = outline.getBounds();
    return Rect.fromLTRB(bounds.left, bounds.bottom - bounds.width, bounds.right, bounds.bottom);
  }
}

abstract final class QuireMark {
  static final Path whole = parseSvgPath(kMarkPathData)..fillType = PathFillType.evenOdd;

  static final List<MarkPane> panes = _panes();

  static final Rect ink = whole.getBounds();

  static final Offset middle = Offset((panes[0].centre.dx + panes[1].centre.dx) / 2, (panes[0].centre.dy + panes[2].centre.dy) / 2);

  static List<MarkPane> _panes() {
    final parts = subpathsOf(kMarkPathData).map(parseSvgPath).toList();
    return [
      MarkPane(outline: parts[0], holes: [parts[1], parts[2]]),
      MarkPane(outline: parts[3], holes: [parts[4]]),
      MarkPane(outline: parts[5], holes: [parts[6]]),
      MarkPane(outline: parts[7], holes: [parts[8]]),
    ];
  }
}
