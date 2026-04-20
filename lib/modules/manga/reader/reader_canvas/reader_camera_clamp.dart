import 'package:flutter/material.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_camera_controller.dart';

@immutable
class CameraClampResult {
  const CameraClampResult({
    required this.translation,
    required this.hitLeft,
    required this.hitRight,
    required this.hitTop,
    required this.hitBottom,
  });

  final Offset translation;
  final bool hitLeft;
  final bool hitRight;
  final bool hitTop;
  final bool hitBottom;
}

class ReaderCameraClamp {
  const ReaderCameraClamp._();

  static CameraClampResult clamp({
    required ReaderCameraState state,
    required Rect sceneBounds,
    required Size viewportSize,
  }) {
    final scaledSceneWidth = sceneBounds.width * state.scale;
    final scaledSceneHeight = sceneBounds.height * state.scale;

    final centeredX =
        viewportSize.width / 2 - sceneBounds.center.dx * state.scale;
    final centeredY =
        viewportSize.height / 2 - sceneBounds.center.dy * state.scale;

    late double minX;
    late double maxX;
    late double minY;
    late double maxY;

    if (scaledSceneWidth <= viewportSize.width) {
      minX = centeredX;
      maxX = centeredX;
    } else {
      minX = viewportSize.width - sceneBounds.right * state.scale;
      maxX = -sceneBounds.left * state.scale;
    }

    if (scaledSceneHeight <= viewportSize.height) {
      minY = centeredY;
      maxY = centeredY;
    } else {
      minY = viewportSize.height - sceneBounds.bottom * state.scale;
      maxY = -sceneBounds.top * state.scale;
    }

    final clampedX = state.translation.dx.clamp(minX, maxX).toDouble();
    final clampedY = state.translation.dy.clamp(minY, maxY).toDouble();

    return CameraClampResult(
      translation: Offset(clampedX, clampedY),
      hitLeft: clampedX == maxX,
      hitRight: clampedX == minX,
      hitTop: clampedY == maxY,
      hitBottom: clampedY == minY,
    );
  }
}
