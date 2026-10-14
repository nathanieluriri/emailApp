import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

typedef FabAction = ({IconData glyph, String label, double offsetY});

const kFabActions = <FabAction>[
  (glyph: LucideIcons.folder, label: 'Open a file', offsetY: -82.0),
  (glyph: LucideIcons.penLine, label: 'Sign a PDF', offsetY: -152.0),
  (glyph: LucideIcons.clock, label: 'Recent', offsetY: -222.0),
];

const kFabRestSize = 60.0;
const kFabRestRadius = 18.0;

const kFabOpenSize = 56.0;
const kFabOpenRadius = kFabOpenSize / 2;

const kFabGlyphSize = 26.0;
const kFabOpenRotationDegrees = 135.0;

const kPillHeight = 52.0;
const kPillRadius = kPillHeight / 2;
const kPillPadding = 20.0;
const kPillGlyphSize = 20.0;
const kPillGap = 12.0;

const kFabCanvasWidth = 220.0;
const kFabCanvasHeight = 340.0;
const kFabCanvasBottomOffset = 8.0;
const kFabRightMargin = 24.0;
const kFabBottomMargin = 24.0;

const kFabCenterX = kFabCanvasWidth - kFabRightMargin - kFabRestSize / 2;
const kFabCenterY = kFabCanvasHeight - kFabBottomMargin - kFabRestSize / 2;

const kGooBlurSigma = 9.0;

const kGooActionDiameter = 50.0;
const kGooButtonRestDiameter = 56.0;
const kGooButtonOpenDiameter = 52.0;

const kGooNeckCircles = 3;

const kGooNeckBreak = 132.0;

const kGooNeckWaist = 0.62;

const kGooAlphaThresholdMatrix = <double>[
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0, //
  0, 0, 1, 0, 0, //
  0, 0, 0, 32, -3570, //
];

const kFabOpenSpring = SpringDescription(mass: 1, stiffness: 130, damping: 14);
const kFabCloseSpring = SpringDescription(mass: 1, stiffness: 190, damping: 17);

const kFabLooseOpenSpring = SpringDescription(mass: 1, stiffness: 130, damping: 13);

const kFabActionStagger = Duration(milliseconds: 60);

const kFabScrimFade = Duration(milliseconds: 200);

const kActionScaleInput = [0.6, 1.0];
const kActionScaleOutput = [0.4, 1.0];
const kActionOpacityInput = [0.65, 1.0];
const kActionOpacityOutput = [0.0, 1.0];

double interpolateClamped(double value, List<double> inputRange, List<double> outputRange) {
  final t = ((value - inputRange[0]) / (inputRange[1] - inputRange[0])).clamp(0.0, 1.0);
  return outputRange[0] + (outputRange[1] - outputRange[0]) * t;
}
