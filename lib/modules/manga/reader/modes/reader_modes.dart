import 'package:mangayomi/models/settings.dart';

const supportedReaderModes = <ReaderMode>[
  ReaderMode.ltr,
  ReaderMode.rtl,
  ReaderMode.vertical,
  ReaderMode.webtoon,
  ReaderMode.verticalContinuous,
];

ReaderMode normalizeReaderMode(ReaderMode mode) {
  return switch (mode) {
    ReaderMode.horizontalContinuous => ReaderMode.webtoon,
    ReaderMode.horizontalContinuousRTL => ReaderMode.webtoon,
    _ => mode,
  };
}

bool isReaderModeContinuous(ReaderMode mode) {
  final normalizedMode = normalizeReaderMode(mode);
  return normalizedMode == ReaderMode.verticalContinuous ||
      normalizedMode == ReaderMode.webtoon;
}

bool isReaderModePaged(ReaderMode mode) => !isReaderModeContinuous(mode);

bool isReaderModeHorizontalPaged(ReaderMode mode) {
  final normalizedMode = normalizeReaderMode(mode);
  return normalizedMode == ReaderMode.ltr || normalizedMode == ReaderMode.rtl;
}

bool isReaderModeLongStripWithGaps(ReaderMode mode) {
  return normalizeReaderMode(mode) == ReaderMode.verticalContinuous;
}
