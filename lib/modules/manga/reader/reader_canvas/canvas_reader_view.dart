import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/navigation_policies.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_camera_controller.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_fling_controller.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene_visibility.dart';

typedef ReaderScenePageBuilder =
    Widget Function(BuildContext context, ReaderScenePage page, Rect viewportRect);

class CanvasReaderViewport extends StatelessWidget {
  const CanvasReaderViewport({
    super.key,
    required this.scene,
    required this.cameraController,
    required this.pageBuilder,
    this.preloadMargin = 400,
    this.backgroundColor,
  });

  final ReaderScene scene;
  final ReaderCameraController cameraController;
  final ReaderScenePageBuilder pageBuilder;
  final double preloadMargin;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );
        cameraController.updateConstraints(
          sceneBounds: scene.bounds,
          viewportSize: viewportSize,
        );

        return AnimatedBuilder(
          animation: cameraController,
          builder: (context, _) {
            final visibleWorldRect = cameraController.visibleWorldRect(
              viewportSize,
            );
            final visiblePages = ReaderSceneVisibility.visiblePages(
              scene: scene,
              visibleWorldRect: visibleWorldRect,
              preloadMargin: preloadMargin,
            );

            return ColoredBox(
              color: backgroundColor ?? Colors.transparent,
              child: ClipRect(
                child: Stack(
                  children: [
                    for (final page in visiblePages)
                      _PositionedScenePage(
                        page: page,
                        cameraController: cameraController,
                        childBuilder: pageBuilder,
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class CanvasReaderView extends StatefulWidget {
  const CanvasReaderView({
    super.key,
    required this.scene,
    required this.cameraController,
    required this.pageBuilder,
    this.preloadMargin = 400,
    this.backgroundColor,
    this.snapPolicy,
    this.onTap,
    this.onDoubleTap,
  });

  final ReaderScene scene;
  final ReaderCameraController cameraController;
  final ReaderScenePageBuilder pageBuilder;
  final double preloadMargin;
  final Color? backgroundColor;
  final ReaderSnapPolicy? snapPolicy;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  @override
  State<CanvasReaderView> createState() => _CanvasReaderViewState();
}

class _CanvasReaderViewState extends State<CanvasReaderView> {
  late final ReaderFlingController _flingController = ReaderFlingController(
    widget.cameraController,
  );

  Offset? _doubleTapPosition;
  double _gestureStartScale = 1;
  bool _gestureWasPinch = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          onDoubleTapDown: (details) {
            _doubleTapPosition = details.localPosition;
          },
          onDoubleTap: _onDoubleTap,
          onScaleStart: (details) {
            _flingController.stop();
            _gestureStartScale = widget.cameraController.state.scale;
            _gestureWasPinch = false;
          },
          onScaleUpdate: (details) {
            if (details.pointerCount > 1) {
              _gestureWasPinch = true;
              widget.cameraController.zoomAround(
                details.localFocalPoint,
                _gestureStartScale * details.scale,
              );
            }
            widget.cameraController.panBy(details.focalPointDelta);
          },
          onScaleEnd: (details) {
            final velocity = details.velocity.pixelsPerSecond;
            if (!_gestureWasPinch && velocity.distance > 550) {
              _flingController.start(velocity * 0.55);
            } else {
              _snapIfNeeded();
            }
          },
          child: CanvasReaderViewport(
            scene: widget.scene,
            cameraController: widget.cameraController,
            pageBuilder: widget.pageBuilder,
            preloadMargin: widget.preloadMargin,
            backgroundColor: widget.backgroundColor,
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.equal ||
        event.logicalKey == LogicalKeyboardKey.numpadAdd) {
      final size = MediaQuery.sizeOf(context);
      widget.cameraController.zoomAround(
        Offset(size.width / 2, size.height / 2),
        widget.cameraController.state.scale * 1.1,
      );
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.minus ||
        event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
      final size = MediaQuery.sizeOf(context);
      widget.cameraController.zoomAround(
        Offset(size.width / 2, size.height / 2),
        widget.cameraController.state.scale / 1.1,
      );
      return KeyEventResult.handled;
    }

    const step = 48.0;
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.cameraController.panBy(const Offset(step, 0));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.cameraController.panBy(const Offset(-step, 0));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      widget.cameraController.panBy(const Offset(0, step));
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.cameraController.panBy(const Offset(0, -step));
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) {
      return;
    }

    final wantsZoom = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (wantsZoom) {
      final delta = event.scrollDelta.dy == 0
          ? event.scrollDelta.dx
          : event.scrollDelta.dy;
      final factor = delta > 0 ? 0.9 : 1.1;
      widget.cameraController.zoomAround(
        event.localPosition,
        widget.cameraController.state.scale * factor,
      );
      return;
    }

    widget.cameraController.panBy(
      Offset(-event.scrollDelta.dx, -event.scrollDelta.dy),
    );
  }

  void _onDoubleTap() {
    final size = MediaQuery.sizeOf(context);
    final tapPosition =
        _doubleTapPosition ?? Offset(size.width / 2, size.height / 2);
    final currentScale = widget.cameraController.state.scale;
    final nextScale = (currentScale - 1).abs() < 0.05 ? 2.0 : 1.0;
    widget.cameraController.zoomAround(tapPosition, nextScale);
    widget.onDoubleTap?.call();
    _snapIfNeeded();
  }

  void _snapIfNeeded() {
    final snapPolicy = widget.snapPolicy;
    if (snapPolicy == null) {
      return;
    }

    final viewportSize = MediaQuery.sizeOf(context);
    final visibleWorldRect = widget.cameraController.visibleWorldRect(
      viewportSize,
    );
    final nearestRect = snapPolicy.nearestSnapRect(
      scene: widget.scene,
      visibleWorldRect: visibleWorldRect,
    );
    if (nearestRect == null) {
      return;
    }

    widget.cameraController.animateTo(
      translation: cameraTranslationForRect(
        targetRect: nearestRect,
        viewportSize: viewportSize,
        scale: widget.cameraController.state.scale,
      ),
    );
  }
}

class _PositionedScenePage extends StatelessWidget {
  const _PositionedScenePage({
    required this.page,
    required this.cameraController,
    required this.childBuilder,
  });

  final ReaderScenePage page;
  final ReaderCameraController cameraController;
  final ReaderScenePageBuilder childBuilder;

  @override
  Widget build(BuildContext context) {
    final topLeft = cameraController.worldToViewport(page.worldRect.topLeft);
    final size = Size(
      page.worldRect.width * cameraController.state.scale,
      page.worldRect.height * cameraController.state.scale,
    );
    final viewportRect = topLeft & size;

    return Positioned(
      key: ValueKey('${page.chapter.id}-${page.pageIndex}'),
      left: viewportRect.left,
      top: viewportRect.top,
      width: viewportRect.width,
      height: viewportRect.height,
      child: childBuilder(context, page, viewportRect),
    );
  }
}
