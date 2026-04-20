import 'package:flutter/widgets.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/manga/reader/modes/reader_modes.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/navigation_policies.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene_builder.dart';

@immutable
class ReaderCanvasModeConfig {
  const ReaderCanvasModeConfig({
    required this.readerMode,
    required this.axis,
    required this.sceneBuilder,
    required this.sceneSettings,
    this.snapPolicy,
    this.isContinuous = false,
    this.isRtl = false,
  });

  final ReaderMode readerMode;
  final Axis axis;
  final ReaderSceneBuilder sceneBuilder;
  final ReaderCanvasSettings sceneSettings;
  final ReaderSnapPolicy? snapPolicy;
  final bool isContinuous;
  final bool isRtl;

  factory ReaderCanvasModeConfig.fromReaderMode(
    ReaderMode mode, {
    double longStripGap = 0,
    double longStripSidePadding = 0,
    double pagedGap = 0,
  }) {
    final normalizedMode = normalizeReaderMode(mode);
    return switch (normalizedMode) {
      ReaderMode.ltr => ReaderCanvasModeConfig(
        readerMode: normalizedMode,
        axis: Axis.horizontal,
        sceneBuilder: const PagedHorizontalSceneBuilder(),
        sceneSettings: ReaderCanvasSettings(pageGap: pagedGap),
        snapPolicy: const PagedLtrSnapPolicy(),
      ),
      ReaderMode.rtl => ReaderCanvasModeConfig(
        readerMode: normalizedMode,
        axis: Axis.horizontal,
        sceneBuilder: const PagedHorizontalSceneBuilder(),
        sceneSettings: ReaderCanvasSettings(pageGap: pagedGap),
        snapPolicy: const PagedRtlSnapPolicy(),
        isRtl: true,
      ),
      ReaderMode.vertical => ReaderCanvasModeConfig(
        readerMode: normalizedMode,
        axis: Axis.vertical,
        sceneBuilder: const PagedVerticalSceneBuilder(),
        sceneSettings: ReaderCanvasSettings(pageGap: pagedGap),
        snapPolicy: const PagedVerticalSnapPolicy(),
      ),
      ReaderMode.verticalContinuous => ReaderCanvasModeConfig(
        readerMode: normalizedMode,
        axis: Axis.vertical,
        sceneBuilder: const LongStripSceneBuilder(),
        sceneSettings: ReaderCanvasSettings(
          pageGap: longStripGap,
          sidePadding: longStripSidePadding,
        ),
        snapPolicy: const LongStripNavigationPolicy(),
        isContinuous: true,
      ),
      _ => ReaderCanvasModeConfig(
        readerMode: normalizedMode,
        axis: Axis.vertical,
        sceneBuilder: const LongStripSceneBuilder(),
        sceneSettings: ReaderCanvasSettings(
          pageGap: 0,
          sidePadding: longStripSidePadding,
        ),
        snapPolicy: const LongStripNavigationPolicy(),
        isContinuous: true,
      ),
    };
  }
}
