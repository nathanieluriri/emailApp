import 'package:flutter/painting.dart';

const kFontFamily = 'Inter';

const kMarkFamily = 'Quicksand';

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

abstract final class AppText {
  static final markName = TextStyle(
    inherit: false,
    fontFamily: kMarkFamily,
    fontSize: 34,
    height: 40 / 34,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
    textBaseline: TextBaseline.alphabetic,
  );

  static final wordmark = _text(size: 30, lineHeight: 34, weight: FontWeight.w700, letterSpacing: 1.4);

  static final wordmarkSmall = _text(size: 17, lineHeight: 22, weight: FontWeight.w600, letterSpacing: 0.6);

  static final display = _text(size: 26, lineHeight: 31, weight: FontWeight.w700, letterSpacing: -0.5);

  static final title = _text(size: 17, lineHeight: 22, weight: FontWeight.w600, letterSpacing: -0.2);

  static final pageHeading1 = _text(size: 24, lineHeight: 30, weight: FontWeight.w700, letterSpacing: -0.4);

  static final pageHeading2 = _text(size: 19, lineHeight: 25, weight: FontWeight.w600, letterSpacing: -0.2);

  static final pageHeading3 = _text(size: 16, lineHeight: 21, weight: FontWeight.w600);

  static final pageBody = _text(size: 15.5, lineHeight: 24);

  static final pageBodyBold = _text(size: 15.5, lineHeight: 24, weight: FontWeight.w600);

  static final pageBodyItalic = _text(size: 15.5, lineHeight: 24, weight: FontWeight.w500, letterSpacing: 0.2);

  static final bodyTight = _text(size: 14, lineHeight: 19);

  static final rowTitle = _text(size: 16, lineHeight: 20);

  static final search = _text(size: 15, lineHeight: 20);

  static final drawerRow = _text(size: 16, lineHeight: 21);
  static final drawerRowSelected = _text(size: 16, lineHeight: 21, weight: FontWeight.w500);

  static final sortLabel = _text(size: 14, lineHeight: 19, weight: FontWeight.w500);

  static final menuRow = _text(size: 15, lineHeight: 20);
  static final menuRowSelected = _text(size: 15, lineHeight: 20, weight: FontWeight.w500);

  static final avatar = _text(size: 15, lineHeight: 20, weight: FontWeight.w600);

  static final destinationTitle = _text(size: 19, lineHeight: 25, weight: FontWeight.w600);
  static final destinationBody = _text(size: 14, lineHeight: 20);

  static final actionPill = _text(size: 15, lineHeight: 20, weight: FontWeight.w500, letterSpacing: -0.1);

  static final docMeta = _text(size: 13, lineHeight: 17);

  static final label = _text(size: 13, lineHeight: 16, weight: FontWeight.w500, letterSpacing: -0.1);

  static final hint = _text(size: 13, lineHeight: 17, weight: FontWeight.w500);

  static final code = _text(size: 13.5, lineHeight: 20, weight: FontWeight.w500, letterSpacing: 0.1, tabular: true);

  static final cell = _text(size: 13, lineHeight: 17, tabular: true);

  static final cellHeader = _text(size: 12, lineHeight: 15, weight: FontWeight.w600, letterSpacing: 0.4);

  static final folio = _text(size: 12, lineHeight: 15, weight: FontWeight.w500, letterSpacing: 1.2, tabular: true);

  static final folioSmall = _text(size: 10, lineHeight: 13, weight: FontWeight.w500, letterSpacing: 1.0, tabular: true);

  static final chipLabel = _text(size: 11, lineHeight: 14, weight: FontWeight.w600, letterSpacing: 0.6);

  static final typeMark = _text(size: 10, lineHeight: 12, weight: FontWeight.w600, letterSpacing: 0.2);

  static final micro = _text(size: 9, lineHeight: 11, weight: FontWeight.w600, letterSpacing: 0.8);
}
