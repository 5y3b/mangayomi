import 'package:flutter/material.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene.dart';

class ReaderSceneVisibility {
  const ReaderSceneVisibility._();

  static Iterable<ReaderScenePage> visiblePages({
    required ReaderScene scene,
    required Rect visibleWorldRect,
    double preloadMargin = 400,
  }) {
    final cullRect = visibleWorldRect.inflate(preloadMargin);
    return scene.pages.where((page) => page.worldRect.overlaps(cullRect));
  }
}
