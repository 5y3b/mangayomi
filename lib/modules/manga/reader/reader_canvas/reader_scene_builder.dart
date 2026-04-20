import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_page_metrics.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';

@immutable
class ReaderCanvasSettings {
  const ReaderCanvasSettings({
    this.pageGap = 0,
    this.sidePadding = 0,
    this.preloadMargin = 400,
    this.fallbackAspectRatio = 0.72,
  });

  final double pageGap;
  final double sidePadding;
  final double preloadMargin;
  final double fallbackAspectRatio;
}

abstract class ReaderSceneBuilder {
  const ReaderSceneBuilder();

  ReaderScene build({
    required List<UChapDataPreload> pages,
    required Size viewportSize,
    required ReaderCanvasSettings settings,
  });
}

class LongStripSceneBuilder extends ReaderSceneBuilder {
  const LongStripSceneBuilder();

  @override
  ReaderScene build({
    required List<UChapDataPreload> pages,
    required Size viewportSize,
    required ReaderCanvasSettings settings,
  }) {
    if (pages.isEmpty) {
      return ReaderScene.empty;
    }

    final contentWidth = math.max(
      1.0,
      viewportSize.width - settings.sidePadding * 2,
    ).toDouble();

    double y = 0;
    final scenePages = <ReaderScenePage>[];
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final metrics = page.isTransitionPage
          ? ReaderPageMetrics(
              baseWidth: viewportSize.width,
              baseHeight: viewportSize.height,
              aspectRatio:
                  viewportSize.width / math.max(viewportSize.height, 1.0),
            )
          : ReaderPageMetrics.fromPage(
              page,
              viewportSize,
              fallbackAspectRatio: settings.fallbackAspectRatio,
              targetWidth: contentWidth,
            );
      final rect = Rect.fromLTWH(
        settings.sidePadding,
        y,
        metrics.baseWidth,
        metrics.baseHeight,
      );
      scenePages.add(
        ReaderScenePage(
          pageIndex: i,
          chapter: page.chapter!,
          worldRect: rect,
          isTransitionPage: page.isTransitionPage,
          data: page,
        ),
      );
      y = rect.bottom + settings.pageGap;
    }

    return ReaderScene(
      pages: scenePages,
      bounds: Rect.fromLTWH(
        0,
        0,
        viewportSize.width,
        math.max(y - settings.pageGap, viewportSize.height),
      ),
    );
  }
}

class PagedHorizontalSceneBuilder extends ReaderSceneBuilder {
  const PagedHorizontalSceneBuilder();

  @override
  ReaderScene build({
    required List<UChapDataPreload> pages,
    required Size viewportSize,
    required ReaderCanvasSettings settings,
  }) {
    if (pages.isEmpty) {
      return ReaderScene.empty;
    }

    final scenePages = <ReaderScenePage>[];
    final slotWidth = viewportSize.width;
    final slotHeight = viewportSize.height;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final metrics = page.isTransitionPage
          ? ReaderPageMetrics(
              baseWidth: viewportSize.width,
              baseHeight: viewportSize.height,
              aspectRatio:
                  viewportSize.width / math.max(viewportSize.height, 1.0),
            )
          : ReaderPageMetrics.fromPage(
              page,
              viewportSize,
              fallbackAspectRatio: settings.fallbackAspectRatio,
            ).fitWithin(viewportSize);
      final slotLeft = i * (slotWidth + settings.pageGap);
      final rect = Rect.fromLTWH(
        slotLeft + (slotWidth - metrics.baseWidth) / 2,
        (slotHeight - metrics.baseHeight) / 2,
        metrics.baseWidth,
        metrics.baseHeight,
      );
      scenePages.add(
        ReaderScenePage(
          pageIndex: i,
          chapter: page.chapter!,
          worldRect: rect,
          isTransitionPage: page.isTransitionPage,
          data: page,
        ),
      );
    }

    final totalWidth =
        pages.length * slotWidth + (math.max(pages.length - 1, 0) * settings.pageGap);
    return ReaderScene(
      pages: scenePages,
      bounds: Rect.fromLTWH(0, 0, totalWidth, slotHeight),
    );
  }
}

class PagedVerticalSceneBuilder extends ReaderSceneBuilder {
  const PagedVerticalSceneBuilder();

  @override
  ReaderScene build({
    required List<UChapDataPreload> pages,
    required Size viewportSize,
    required ReaderCanvasSettings settings,
  }) {
    if (pages.isEmpty) {
      return ReaderScene.empty;
    }

    final scenePages = <ReaderScenePage>[];
    final slotWidth = viewportSize.width;
    final slotHeight = viewportSize.height;
    for (var i = 0; i < pages.length; i++) {
      final page = pages[i];
      final metrics = page.isTransitionPage
          ? ReaderPageMetrics(
              baseWidth: viewportSize.width,
              baseHeight: viewportSize.height,
              aspectRatio:
                  viewportSize.width / math.max(viewportSize.height, 1.0),
            )
          : ReaderPageMetrics.fromPage(
              page,
              viewportSize,
              fallbackAspectRatio: settings.fallbackAspectRatio,
            ).fitWithin(viewportSize);
      final slotTop = i * (slotHeight + settings.pageGap);
      final rect = Rect.fromLTWH(
        (slotWidth - metrics.baseWidth) / 2,
        slotTop + (slotHeight - metrics.baseHeight) / 2,
        metrics.baseWidth,
        metrics.baseHeight,
      );
      scenePages.add(
        ReaderScenePage(
          pageIndex: i,
          chapter: page.chapter!,
          worldRect: rect,
          isTransitionPage: page.isTransitionPage,
          data: page,
        ),
      );
    }

    final totalHeight =
        pages.length * slotHeight + (math.max(pages.length - 1, 0) * settings.pageGap);
    return ReaderScene(
      pages: scenePages,
      bounds: Rect.fromLTWH(0, 0, slotWidth, totalHeight),
    );
  }
}
