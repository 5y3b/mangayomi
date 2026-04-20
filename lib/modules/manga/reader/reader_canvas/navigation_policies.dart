import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene.dart';

abstract class ReaderSnapPolicy {
  const ReaderSnapPolicy();

  Rect? targetPageRectForNext({
    required ReaderScene scene,
    required int currentPageIndex,
  });

  Rect? targetPageRectForPrevious({
    required ReaderScene scene,
    required int currentPageIndex,
  });

  Rect? nearestSnapRect({
    required ReaderScene scene,
    required Rect visibleWorldRect,
  });
}

class PagedLtrSnapPolicy extends ReaderSnapPolicy {
  const PagedLtrSnapPolicy();

  @override
  Rect? targetPageRectForNext({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex + 1);

  @override
  Rect? targetPageRectForPrevious({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex - 1);

  @override
  Rect? nearestSnapRect({
    required ReaderScene scene,
    required Rect visibleWorldRect,
  }) => _nearestByCenter(scene, visibleWorldRect.center);
}

class PagedRtlSnapPolicy extends ReaderSnapPolicy {
  const PagedRtlSnapPolicy();

  @override
  Rect? targetPageRectForNext({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex - 1);

  @override
  Rect? targetPageRectForPrevious({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex + 1);

  @override
  Rect? nearestSnapRect({
    required ReaderScene scene,
    required Rect visibleWorldRect,
  }) => _nearestByCenter(scene, visibleWorldRect.center);
}

class PagedVerticalSnapPolicy extends ReaderSnapPolicy {
  const PagedVerticalSnapPolicy();

  @override
  Rect? targetPageRectForNext({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex + 1);

  @override
  Rect? targetPageRectForPrevious({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex - 1);

  @override
  Rect? nearestSnapRect({
    required ReaderScene scene,
    required Rect visibleWorldRect,
  }) => _nearestByCenter(scene, visibleWorldRect.center);
}

class LongStripNavigationPolicy extends ReaderSnapPolicy {
  const LongStripNavigationPolicy();

  @override
  Rect? targetPageRectForNext({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex + 1);

  @override
  Rect? targetPageRectForPrevious({
    required ReaderScene scene,
    required int currentPageIndex,
  }) => _rectAt(scene, currentPageIndex - 1);

  @override
  Rect? nearestSnapRect({
    required ReaderScene scene,
    required Rect visibleWorldRect,
  }) => _nearestByCenter(scene, visibleWorldRect.topCenter);
}

Rect? _rectAt(ReaderScene scene, int index) {
  if (index < 0 || index >= scene.pages.length) {
    return null;
  }
  return scene.pages[index].worldRect;
}

Rect? _nearestByCenter(ReaderScene scene, Offset point) {
  if (scene.pages.isEmpty) {
    return null;
  }

  ReaderScenePage? nearestPage;
  var nearestDistance = double.infinity;
  for (final page in scene.pages) {
    final distance = (page.worldRect.center - point).distanceSquared;
    if (distance < nearestDistance) {
      nearestPage = page;
      nearestDistance = distance;
    }
  }
  return nearestPage?.worldRect;
}

Offset cameraTranslationForRect({
  required Rect targetRect,
  required Size viewportSize,
  required double scale,
}) {
  final viewportCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
  final targetCenter = targetRect.center;
  return viewportCenter - targetCenter * math.max(scale, 0.01);
}
