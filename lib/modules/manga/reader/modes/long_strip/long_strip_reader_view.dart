import 'package:flutter/material.dart';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:mangayomi/modules/manga/reader/modes/long_strip/long_strip_image_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/long_strip/long_strip_transition_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/reader_modes.dart';
import 'package:mangayomi/modules/manga/reader/widgets/double_page_view.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/more/settings/reader/reader_screen.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:mangayomi/models/settings.dart';

/// Main widget for virtual reading that replaces ScrollablePositionedList
class ImageViewWebtoon extends StatelessWidget {
  final Key? containerKey;
  final List<UChapDataPreload> pages;
  final ItemScrollController itemScrollController;
  final ScrollOffsetController scrollOffsetController;
  final ItemPositionsListener itemPositionsListener;
  final Axis scrollDirection;
  final double minCacheExtent;
  final int initialScrollIndex;
  final ScrollPhysics physics;
  final Function(UChapDataPreload data) onLongPressData;
  final Function(bool) onFailedToLoadImage;
  final BackgroundColor backgroundColor;
  final bool isDoublePageMode;
  final bool isHorizontalContinuous;
  final ReaderMode readerMode;
  final double scale;
  final Offset panOffset;
  final void Function(PointerSignalEvent)? onPointerSignal;
  final void Function(PointerDownEvent)? onPointerDown;
  final void Function(PointerMoveEvent)? onPointerMove;
  final void Function(PointerUpEvent)? onPointerUp;
  final void Function(PointerCancelEvent)? onPointerCancel;
  final Function(Offset) onDoubleTapDown;
  final VoidCallback onDoubleTap;
  final int webtoonSidePadding;
  final bool showPageGaps;
  final bool reverse;
  final ValueNotifier<bool> isScrolling;

  const ImageViewWebtoon({
    super.key,
    this.containerKey,
    required this.pages,
    required this.itemScrollController,
    required this.scrollOffsetController,
    required this.itemPositionsListener,
    required this.scrollDirection,
    required this.minCacheExtent,
    required this.initialScrollIndex,
    required this.physics,
    required this.onLongPressData,
    required this.onFailedToLoadImage,
    required this.backgroundColor,
    required this.isDoublePageMode,
    required this.isHorizontalContinuous,
    required this.readerMode,
    required this.scale,
    required this.panOffset,
    this.onPointerSignal,
    this.onPointerDown,
    this.onPointerMove,
    this.onPointerUp,
    this.onPointerCancel,
    required this.onDoubleTapDown,
    required this.onDoubleTap,
    required this.isScrolling,
    this.webtoonSidePadding = 0,
    this.showPageGaps = true,
    this.reverse = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const scaleAlignment = Alignment.center;
        final safeScale = math.max(scale, 0.01);
        final logicalViewportWidth =
            scale < 1 && scrollDirection == Axis.horizontal
            ? constraints.maxWidth / safeScale
            : constraints.maxWidth;
        final logicalViewportHeight =
            scale < 1 && scrollDirection == Axis.vertical
            ? constraints.maxHeight / safeScale
            : constraints.maxHeight;
        final effectiveCacheExtent = scale < 1
            ? minCacheExtent / safeScale
            : minCacheExtent;

        Widget content = ScrollablePositionedList.separated(
          scrollDirection: scrollDirection,
          reverse: reverse,
          minCacheExtent: effectiveCacheExtent,
          initialScrollIndex: initialScrollIndex,
          itemCount: pages.length,
          physics: physics,
          itemScrollController: itemScrollController,
          scrollOffsetController: scrollOffsetController,
          itemPositionsListener: itemPositionsListener,
          itemBuilder: (context, index) => _buildItem(context, index),
          separatorBuilder: _buildSeparator,
        );

        content = Align(
          alignment: scaleAlignment,
          child: Transform.translate(
            offset: panOffset,
            child: Transform.scale(
              scale: scale,
              alignment: scaleAlignment,
              child: OverflowBox(
                alignment: scaleAlignment,
                minWidth: logicalViewportWidth,
                maxWidth: logicalViewportWidth,
                minHeight: logicalViewportHeight,
                maxHeight: logicalViewportHeight,
                child: SizedBox(
                  width: logicalViewportWidth,
                  height: logicalViewportHeight,
                  child: content,
                ),
              ),
            ),
          ),
        );

        return Listener(
          key: containerKey,
          behavior: HitTestBehavior.translucent,
          onPointerSignal: onPointerSignal,
          onPointerDown: onPointerDown,
          onPointerMove: onPointerMove,
          onPointerUp: onPointerUp,
          onPointerCancel: onPointerCancel,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: content,
          ),
        );
      },
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final currentPage = pages[index];
    final uniqueKey = ValueKey(
      '${currentPage.chapter?.id ?? "trans"}-${currentPage.index ?? index}',
    );

    return KeyedSubtree(
      key: uniqueKey,
      child: (isDoublePageMode && !isHorizontalContinuous)
          ? _buildDoublePageItem(context, index)
          : _buildSinglePageItem(context, index),
    );
  }

  Widget _buildSinglePageItem(BuildContext context, int index) {
    final currentPage = pages[index];
    final double sidePad = webtoonSidePadding > 0
        ? MediaQuery.of(context).size.width * webtoonSidePadding / 100
        : 0;

    if (currentPage.isTransitionPage) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
        onDoubleTap: onDoubleTap,
        child: TransitionViewVertical(data: currentPage),
      );
    }

    return Padding(
      padding: isHorizontalContinuous
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(horizontal: sidePad),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
        onDoubleTap: onDoubleTap,
        child: ImageViewVertical(
          data: currentPage,
          failedToLoadImage: onFailedToLoadImage,
          onLongPressData: onLongPressData,
          isHorizontal: isHorizontalContinuous,
          isScrolling: isScrolling,
        ),
      ),
    );
  }

  Widget _buildDoublePageItem(BuildContext context, int index) {
    final pageLength = pages.length;
    if (index >= pageLength) {
      return const SizedBox.shrink();
    }

    final int index1 = index * 2 - 1;
    final int index2 = index1 + 1;

    final List<UChapDataPreload?> datas = index == 0
        ? [pages[0], null]
        : [
            index1 < pageLength ? pages[index1] : null,
            index2 < pageLength ? pages[index2] : null,
          ];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: (details) => onDoubleTapDown(details.globalPosition),
      onDoubleTap: onDoubleTap,
      child: DoublePageView.vertical(
        pages: datas,
        backgroundColor: backgroundColor,
        onFailedToLoadImage: onFailedToLoadImage,
        onLongPressData: onLongPressData,
      ),
    );
  }

  Widget _buildSeparator(BuildContext context, int index) {
    if (!showPageGaps || !isReaderModeLongStripWithGaps(readerMode)) {
      return const SizedBox.shrink();
    }

    if (isHorizontalContinuous) {
      return VerticalDivider(
        color: getBackgroundColor(backgroundColor),
        width: 6,
      );
    } else {
      return Divider(color: getBackgroundColor(backgroundColor), height: 6);
    }
  }
}
