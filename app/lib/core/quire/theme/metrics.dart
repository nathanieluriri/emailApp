import 'package:flutter/painting.dart';

const kSpace4 = 4.0;
const kSpace8 = 8.0;
const kSpace12 = 12.0;
const kSpace14 = 14.0;
const kSpace16 = 16.0;
const kSpace20 = 20.0;
const kSpace24 = 24.0;
const kSpace26 = 26.0;
const kSpace32 = 32.0;
const kSpace40 = 40.0;
const kSpace56 = 56.0;

const kSpacingScale = <double>[kSpace4, kSpace8, kSpace12, kSpace14, kSpace16, kSpace20, kSpace24, kSpace26, kSpace32, kSpace40, kSpace56];

const kScreenWidth = 402.0;
const kScreenHeight = 874.0;
const kSafeTop = 62.0;
const kSafeBottom = 34.0;
const kScreenPadding = 20.0;
const kDeskHeaderTop = 62.0;

const kDeskHeaderHeight = 56.0;
const kChipRowTop = 124.0;
const kChipHeight = 30.0;
const kChipGap = 10.0;
const kChipPaddingX = 11.0;
const kChipUnderlineHeight = 2.0;

const kChipUnderlineGap = 6.0;
const kCardListTop = 176.0;

const kCardWidth = 362.0;
const kCardHeight = 96.0;
const kCardGap = 12.0;
const kCardPadding = 14.0;

const kCardTextLeft = 58.0;

const kCardFoldRestInset = 16.0;
const kCardProgressWidth = 120.0;
const kCardProgressHeight = 2.0;

const kTypeMarkSize = 30.0;

const kTypeMarkGridSize = 20.0;

const kTypeMarkOpeningSize = kTypeMarkSize * 2;

const kTypeMarkRadius = 8.0;

const kTypeMarkLettersTop = 9.0;

const kColophonRuleWidth = 120.0;

const kDeskListBottomPadding = 130.0;
const kHeaderButtonSize = 38.5;
const kHeaderButtonRadius = 14.0;

const kSmallTitleRange = (22.0, 58.0);
const kLargeTitleRange = (0.0, 44.0);
const kOverscrollRange = (-80.0, 0.0);
const kOverscrollScale = 1.08;
const kTitleShift = 8.0;

double rangeProgress(double value, (double, double) range) {
  final (start, end) = range;
  return ((value - start) / (end - start)).clamp(0, 1);
}

const kSheetLeft = 0.0;

const kSheetTop = 0.0;
const kSheetWidth = kScreenWidth;
const kSheetHeight = kScreenHeight;

double readerBandHeight(EdgeInsets safeArea) => safeArea.top + kHeadBandHeight;

double readerContentTop(EdgeInsets safeArea) => readerBandHeight(safeArea);

double readerContentBottom(EdgeInsets safeArea) => safeArea.bottom + 8;

const kReaderContentTop = kHeadBandTop + kHeadBandHeight;
const kReaderContentBottom = kSafeBottom + 8;

const kReadableTop = kSafeTop;
const kReadableBottom = kScreenHeight - kSafeBottom;

const kSheetPadding = 26.0;

const kProseMeasure = kSheetWidth - 2 * kSheetPadding;
const kHeadBandTop = 62.0;

const kHeadBandHeight = 52.0;

const kForeEdgeLeft = kScreenWidth - kForeEdgeWidth - 2;

const kForeEdgeWidth = 16.0;

const kForeEdgeTop = kReaderContentTop;

const kForeEdgeHeight = kReadableBottom - kReaderContentTop;

const kForeEdgeHitLeft = kForeEdgeLeft - 26;

const kForeEdgeHitBottom = kReadableBottom - kCornerHandle;

const kCornerHandle = 72.0;

const kFoldRestInset = 16.0;

const kFoldEdgeMargin = 4.0;

const kDogEarInset = 14.0;

const kDogEarCatchFraction = 0.6;

const kFlipCommitFraction = 0.55;
const kFolioChipWidth = 76.0;
const kFolioChipHeight = 30.0;

const kFolioChipInset = 12.0;

const kPageRule = 1.0;
const kBackDragCommit = 96.0;

const kBackDragVelocity = 400.0;

const kBackEdgeZone = 24.0;

const kRowHeaderWidth = 40.0;
const kSpineWidth = 12.0;
const kSpineWidthMax = 28.0;
const kOpenColumnMin = 160.0;
const kOpenColumnMax = 272.0;
const kTableHeaderHeight = 32.0;
const kTableRowHeight = 30.0;
const kCellPaddingX = 8.0;
const kSheetTabHeight = 44.0;

const kSheetTabPill = 30.0;
const kSheetTabPadX = 14.0;

const kSheetTabGlyph = 19.0;
const kParseStripHeight = 20.0;
const kCellBarHeight = 64.0;

const kCellBarNoteHeight = 52.0;
const kCellBarPadX = 12.0;
const kCellBarPadY = 10.0;
const kCellBarWellRadius = 22.0;

const kGridHeaderHeight = 34.0;

const kGridColumnWidth = 118.0;
const kGridColumnMin = 40.0;
const kGridColumnMax = 720.0;

const kGridRowHeight = 34.0;
const kGridRowMin = 22.0;
const kGridRowMax = 400.0;

const kSheetColumnPoints = 64.0;
const kSheetRowPoints = 20.0;

const kGridCellPadX = 8.0;

const kGridCellPadY = 5.0;

const kGridCommentMark = 7.0;

const kGridRingWidth = 2.0;
const kGridHandle = 5.0;

const kGridLitRound = 9.0;

const kSheetTabTravel = Duration(milliseconds: 680);

const kGridGooInset = 3.0;

const kGridPullGive = 0.5;
const kGridPullMax = 220.0;

const kGridFlingFrom = 120.0;

const double kGridFriction = 0.015;

const kGridTopCarry = kHeadBandHeight;
const kSpineBarMax = 10.0;
const kSpineBarHeight = 2.0;
const kSpineDot = 4.0;

const kLeaderEvery = 5;

({double open, double spine}) columnWidths(int columns) {
  final spines = columns - 1;
  const avail = kSheetWidth - kRowHeaderWidth; // 332
  if (spines <= 0) return (open: avail, spine: 0);
  var spine = kSpineWidth;
  var open = avail - spines * spine;
  if (open > kOpenColumnMax) {
    spine = ((avail - kOpenColumnMax) / spines).clamp(kSpineWidth, kSpineWidthMax);
    open = avail - spines * spine;
  }
  return (open: open.clamp(kOpenColumnMin, avail), spine: spine);
}

const kFindFieldHeight = 38.5;
const kChevronSize = 32.0;
const kMatchTick = 2.0;
const kMatchTickLive = 4.0;

const kMatchTickMerge = 3.0;
const kRiffleSlotHeight = 132.0;
const kRiffleThumbWidth = 84.0;
const kRiffleThumbHeight = 108.0;
const kRiffleScrimOpacity = 0.88;
const kRiffleThumbScale = 84.0 / 372.0;

const kRiffleCollapseBelow = 6.0;
const kArcRadius = 520.0;
const kMaxTiltDeg = 14.0;
const kItemTiltInfluence = 0.2;
const kMaxScaleShrink = 0.12;
const kCenterDistanceClamp = 1.2;
const kTopFadeHeight = 96.0;
const kBottomFadeHeight = 160.0;
const kBottomGradientHeight = 56.0;
const kDockGap = 18.0;
const kDockButtonSize = 54.0;
const kDockButtonSpacing = 78.0;
const kDockHoverScale = 1.18;
const kDockHoverRadius = kDockButtonSize * 0.85;
const kDockEnterRise = 25.0;
const kPadLeft = 20.0;
const kPadTop = 150.0;
const kPadWidth = 362.0;
const kPadHeight = 240.0;
const kPadBaselineFraction = 0.70;

const kPadRadius = 14.0;
const kStampInitialWidth = 200.0;

const kStampScaleMin = 0.25;
const kStampScaleMax = 2.0;
const kBaselineSnapDistance = 4.0;
const kChromeDimAmount = 0.78;
const kDimmedCardOpacity = 0.25;
const kLiftScaleDelta = 0.02;
const kPlacementDim = 0.86;
const kShimmerBand = 96.0;
const kShimmerOpacity = 0.28;
const kShimmerSkew = 14.0;

const kLeafRadius = 3.0;

const kPeelableCorner = BorderRadius.only(
  topLeft: Radius.circular(kLeafRadius),
  topRight: Radius.circular(kLeafRadius),
  bottomLeft: Radius.circular(kLeafRadius),
);

const kChipRadius = 8.0;

const kFieldRadius = 14.0;

const kPillRadius = 999.0;

const kCodeRadius = 6.0;

const kInlineCodeRadius = 4.0;

const kMarkRadius = 2.0;

const kPress = Duration(milliseconds: 90);

const kWashRadius = 12.0;

const kWashRise = Duration(milliseconds: 220);
const kWashSink = Duration(milliseconds: 160);

const kWashFlood = Duration(milliseconds: 380);

const kWashOpacity = 0.22;

const kWashBlurSigma = 5.0;

const kTabTravel = Duration(milliseconds: 340);

const kListRowWashRadius = 14.0;

const kPeelLongPress = Duration(milliseconds: 140);

const kDogEarCatchHold = Duration(milliseconds: 200);

const kLift = Duration(milliseconds: 180);

const kDim = Duration(milliseconds: 220);

const kChipUnderline = Duration(milliseconds: 220);

const kSearchOpen = Duration(milliseconds: 220);
const kSearchClose = Duration(milliseconds: 160);

const kOpenDocument = Duration(milliseconds: 320);
const kCloseDocument = Duration(milliseconds: 300);

const kFlipCommit = Duration(milliseconds: 380);

const kDeskWaking = Duration(seconds: 1);

const kDeskWakingLimit = Duration(seconds: 2);

const kDeskWakingFade = Duration(milliseconds: 150);

const kOpeningLimit = Duration(seconds: 8);

const kChromeIn = Duration(milliseconds: 180);

const kSweepPerWord = Duration(milliseconds: 140);

const kSweepStagger = Duration(milliseconds: 24);

const kSweepCap = Duration(milliseconds: 400);

const kSweepLive = Duration(milliseconds: 120);

const kDigitRoll = Duration(milliseconds: 120);

const kDigitStagger = Duration(milliseconds: 20);

const kRailFade = Duration(milliseconds: 200);

const kColumnOpen = Duration(milliseconds: 240);

const kSheetTabCross = Duration(milliseconds: 360);

const kDissolve = Duration(milliseconds: 3000);

const kMaterialize = Duration(milliseconds: 1200);

const kAbsorb = Duration(milliseconds: 900);

const kUndoPill = Duration(milliseconds: 4000);

const kInkDry = Duration(milliseconds: 900);

const kPageFadeIn = Duration(milliseconds: 160);

const kShimmerPeriod = Duration(milliseconds: 640);

const kRiffleIn = Duration(milliseconds: 220);
const kRiffleOut = Duration(milliseconds: 180);

const kRiffleCommit = Duration(milliseconds: 300);

const kFoldRest = Duration(milliseconds: 260);

const kStampOutlineFade = Duration(milliseconds: 160);

const kStampSettle = Duration(milliseconds: 220);

const kSnapGuideHold = Duration(milliseconds: 220);
const kSnapGuideFade = Duration(milliseconds: 180);

const kStateCardIn = Duration(milliseconds: 240);

const kDockEnter = Duration(milliseconds: 260);
const kDockExit = Duration(milliseconds: 140);
const kDockEnterStagger = Duration(milliseconds: 50);
const kDockHover = Duration(milliseconds: 180);

double dockButtonCenterX(int index, double containerWidth, int actionCount) {
  final middle = (actionCount - 1) / 2;
  return containerWidth / 2 + (index - middle) * kDockButtonSpacing;
}

double dockRowCenterY(double sheetHeight) => sheetHeight + kDockGap + kDockButtonSize / 2;

const kTopBarHeight = 56.0;
const kTopBarPaddingX = 12.0;

const kBurgerTarget = 40.0;
const kBurgerLine = 18.0;
const kBurgerThickness = 2.0;
const kBurgerGap = 5.0;

const kBurgerLineShort = 9.0;
const kBurgerShift = 4.0;
const kBurgerAngle = 45.0;

const kSearchPillHeight = 44.0;
const kSearchPillRadius = 22.0;

const kSearchFolderTarget = 36.0;
const kAvatarSize = 34.0;

const kDrawerWidthFraction = 0.84;
const kDrawerWidthMax = 320.0;

double drawerWidth(double screenWidth) => (screenWidth * kDrawerWidthFraction).clamp(0, kDrawerWidthMax);

const kDrawerRowHeight = 52.0;
const kDrawerRowRadius = 26.0;
const kDrawerRowPaddingX = 16.0;
const kDrawerRowGlyph = 24.0;

const kDrawerRowGap = 24.0;

const kDrawerDividerInset = 16.0;

const kTabStripHeight = 44.0;
const kTabStripPaddingX = 12.0;
const kTabGap = 8.0;
const kTabPillHeight = 32.0;
const kTabPillRadius = 16.0;
const kTabPillPaddingX = 14.0;

const kTabCountGap = 6.0;

const kSortRowHeight = 48.0;
const kSortRowPaddingX = 12.0;

const kSortArrowCircle = 24.0;
const kSortArrowFlip = Duration(milliseconds: 200);

const kViewToggleWidth = 40.0;
const kViewToggleHeight = 32.0;
const kViewToggleRadius = 16.0;
const kViewToggleGap = 8.0;

const kSortMenuWidth = 240.0;
const kSortMenuRadius = 12.0;
const kSortMenuOffset = 8.0;
const kSortMenuRowHeight = 48.0;
const kSortMenuPaddingLeft = 16.0;
const kSortMenuPaddingRight = 20.0;

const kSortMenuGutter = 40.0;
const kSortMenuCheck = 18.0;
const kSortMenuIn = Duration(milliseconds: 160);

const kPadArrival = Duration(milliseconds: 260);

const kReaderNotice = Duration(seconds: 4);

const kOverflowOozeIn = Duration(milliseconds: 300);

const kSortMenuScaleFrom = 0.94;

const kListRowHeight = 72.0;
const kListRowPaddingX = 12.0;

const kListRuleInset = 64.0;

const kListMarkGap = 14.0;

const kListTitleGap = 4.0;

const kOverflowTarget = 40.0;
const kOverflowDot = 4.0;
const kOverflowDotGap = 3.0;

const kOverflowMenuGutter = 32.0;
const kOverflowMenuGlyph = 17.0;
const kOverflowMenuOffset = 4.0;

const kOverflowMenuMargin = 12.0;

const kOverflowOriginInset = 22.0;

const kListProgressWidth = 140.0;
const kListProgressHeight = 2.0;

const kGridColumns = 2;
const kGridGap = 12.0;
const kGridPadding = 12.0;
const kGridCardRadius = 12.0;

const kGridCardHeaderHeight = 44.0;
const kGridCardPadding = 10.0;

const kGridHeaderGap = 8.0;
const kGridOverflowTarget = 32.0;

const kThumbnailAspect = 1 / 1.15;

const kHairline = 1.0;
