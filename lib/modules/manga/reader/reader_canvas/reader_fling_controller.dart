import 'package:flutter/material.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_camera_controller.dart';

class ReaderFlingController {
  const ReaderFlingController(this.cameraController);

  final ReaderCameraController cameraController;

  void start(Offset velocity) {
    cameraController.fling(velocity);
  }

  void stop() {
    cameraController.stopMotion();
  }
}
