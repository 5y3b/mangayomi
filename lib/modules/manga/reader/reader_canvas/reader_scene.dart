import 'package:flutter/material.dart';
import 'package:mangayomi/models/chapter.dart';

@immutable
class ReaderScenePage {
  const ReaderScenePage({
    required this.pageIndex,
    required this.chapter,
    required this.worldRect,
    required this.isTransitionPage,
    required this.data,
  });

  final int pageIndex;
  final Chapter chapter;
  final Rect worldRect;
  final bool isTransitionPage;
  final Object? data;
}

@immutable
class ReaderScene {
  const ReaderScene({
    required this.pages,
    required this.bounds,
  });

  final List<ReaderScenePage> pages;
  final Rect bounds;

  static const empty = ReaderScene(
    pages: <ReaderScenePage>[],
    bounds: Rect.zero,
  );
}
