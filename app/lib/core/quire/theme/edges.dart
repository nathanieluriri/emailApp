import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'metrics.dart';

double hairline(BuildContext context) => kHairline / MediaQuery.devicePixelRatioOf(context);

abstract final class AppEdges {
  static BorderSide side(BuildContext context) => BorderSide(color: AppColors.hairline, width: hairline(context));

  static Border all(BuildContext context) => Border.fromBorderSide(side(context));
}
