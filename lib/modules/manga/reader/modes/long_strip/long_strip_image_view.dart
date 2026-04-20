import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/widgets/color_filter_widget.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/utils/extensions/others.dart';
import 'package:mangayomi/modules/manga/reader/widgets/circular_progress_indicator_animate_rotate.dart';

class ImageViewVertical extends ConsumerWidget {
  final UChapDataPreload data;
  final Function(UChapDataPreload data) onLongPressData;
  final bool isHorizontal;
  final ValueNotifier<bool> isScrolling;
  final VoidCallback? onMetricsChanged;
  final bool fillParent;

  final Function(bool) failedToLoadImage;

  const ImageViewVertical({
    super.key,
    required this.data,
    required this.onLongPressData,
    required this.failedToLoadImage,
    required this.isHorizontal,
    required this.isScrolling,
    this.onMetricsChanged,
    this.fillParent = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (colorBlendMode, color) = chapterColorFIlterValues(context, ref);
    void notifyFailedToLoadImage(bool value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        failedToLoadImage(value);
      });
    }

    void notifyMetricsChanged() {
      if (onMetricsChanged == null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onMetricsChanged?.call();
      });
    }

    Widget buildCanvasBoundedChild(Widget child) {
      if (!fillParent) {
        return child;
      }
      return SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      );
    }

    final imageWidget = ValueListenableBuilder<bool>(
      valueListenable: isScrolling,
      builder: (context, scrolling, _) => ExtendedImage(
        colorBlendMode: colorBlendMode,
        color: color,
        image: data.getImageProvider(ref, true),
        filterQuality: scrolling ? FilterQuality.low : FilterQuality.medium,
        handleLoadingProgress: true,
        fit: getBoxFit(ref.watch(scaleTypeStateProvider)),
        enableLoadState: true,
        loadStateChanged: (state) {
          if (state.extendedImageLoadState == LoadState.completed) {
            notifyFailedToLoadImage(false);
            final rawSize = state.extendedImageInfo?.image;
            if (rawSize != null && data.loadedHeight == null) {
              final screenWidth = isHorizontal
                  ? context.width(0.8)
                  : MediaQuery.of(context).size.width;
              final aspect = rawSize.width / rawSize.height;
              data.loadedWidth = screenWidth;
              data.loadedHeight = screenWidth / aspect;
              notifyMetricsChanged();
            }
          }
          final placeholderHeight = fillParent
              ? double.infinity
              : (data.loadedHeight ?? context.height(0.8));
          final placeholderWidth = fillParent
              ? double.infinity
              : isHorizontal
              ? (data.loadedWidth ?? context.width(0.8))
              : null;
          if (state.extendedImageLoadState == LoadState.loading) {
            final ImageChunkEvent? loadingProgress = state.loadingProgress;
            final double progress = loadingProgress?.expectedTotalBytes != null
                ? loadingProgress!.cumulativeBytesLoaded /
                      loadingProgress.expectedTotalBytes!
                : 0;
            return Container(
              color: Colors.black,
              height: placeholderHeight,
              width: placeholderWidth,
              child: buildCanvasBoundedChild(
                CircularProgressIndicatorAnimateRotate(progress: progress),
              ),
            );
          }
          if (state.extendedImageLoadState == LoadState.failed) {
            notifyFailedToLoadImage(true);
            return Container(
              color: Colors.black,
              height: placeholderHeight,
              width: placeholderWidth,
              child: buildCanvasBoundedChild(
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.image_loading_error,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GestureDetector(
                        onLongPress: () {
                          state.reLoadImage();
                          notifyFailedToLoadImage(false);
                        },
                        onTap: () {
                          state.reLoadImage();
                          notifyFailedToLoadImage(false);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.primaryColor,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 16,
                            ),
                            child: Text(context.l10n.retry),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return null;
        },
      ),
    );
    return applyReaderColorFilter(
      GestureDetector(
        onLongPress: () => onLongPressData.call(data),
        child: fillParent
            ? SizedBox.expand(child: imageWidget)
            : isHorizontal
            ? imageWidget
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (data.index == 0)
                    SizedBox(height: MediaQuery.of(context).padding.top),
                  imageWidget,
                ],
              ),
      ),
      ref,
    );
  }
}
