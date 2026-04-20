import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';

@immutable
class ReaderPageMetrics {
  const ReaderPageMetrics({
    required this.baseWidth,
    required this.baseHeight,
    required this.aspectRatio,
  });

  final double baseWidth;
  final double baseHeight;
  final double aspectRatio;

  Size get size => Size(baseWidth, baseHeight);

  static ReaderPageMetrics fromPage(
    UChapDataPreload page,
    Size viewportSize, {
    double fallbackAspectRatio = 0.72,
    double? targetWidth,
    double? targetHeight,
  }) {
    final rawWidth = page.loadedWidth;
    final rawHeight = page.loadedHeight;
    final aspectRatio = rawWidth != null &&
            rawHeight != null &&
            rawWidth > 0 &&
            rawHeight > 0
        ? rawWidth / rawHeight
        : fallbackAspectRatio;

    final fittedWidth = targetWidth ??
        (targetHeight != null ? targetHeight * aspectRatio : viewportSize.width);
    final fittedHeight =
        targetHeight ?? (fittedWidth / math.max(aspectRatio, 0.01));

    return ReaderPageMetrics(
      baseWidth: fittedWidth,
      baseHeight: fittedHeight,
      aspectRatio: aspectRatio,
    );
  }

  ReaderPageMetrics fitWithin(Size viewportSize) {
    final widthScale = viewportSize.width / math.max(baseWidth, 0.01);
    final heightScale = viewportSize.height / math.max(baseHeight, 0.01);
    final scale = math.min(widthScale, heightScale);
    return ReaderPageMetrics(
      baseWidth: baseWidth * scale,
      baseHeight: baseHeight * scale,
      aspectRatio: aspectRatio,
    );
  }
}
