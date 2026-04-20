import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:extended_image/extended_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mangayomi/main.dart';
import 'package:mangayomi/models/chapter.dart';
import 'package:mangayomi/models/settings.dart';
import 'package:mangayomi/modules/anime/widgets/desktop.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_gestures.dart';
import 'package:mangayomi/modules/manga/reader/providers/crop_borders_provider.dart';
import 'package:mangayomi/modules/manga/reader/services/page_navigation_service.dart';
import 'package:mangayomi/modules/manga/reader/mixins/reader_memory_management.dart';
import 'package:mangayomi/modules/manga/reader/widgets/double_page_view.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_app_bar.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_bottom_bar.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_gesture_handler.dart';
import 'package:mangayomi/modules/manga/reader/widgets/reader_settings_modal.dart';
import 'package:mangayomi/modules/manga/reader/widgets/auto_scroll_button.dart';
import 'package:mangayomi/modules/manga/reader/widgets/page_indicator.dart';
import 'package:mangayomi/modules/manga/reader/widgets/image_actions_dialog.dart';
import 'package:mangayomi/modules/manga/reader/modes/long_strip/long_strip_reader_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/long_strip/long_strip_image_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/long_strip/long_strip_transition_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/paged/paged_image_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/paged/paged_transition_view.dart';
import 'package:mangayomi/modules/manga/reader/modes/reader_modes.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/canvas_reader_view.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/navigation_policies.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_camera_controller.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_mode_config.dart';
import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_scene.dart';
import 'package:mangayomi/modules/more/settings/reader/providers/reader_state_provider.dart';
import 'package:mangayomi/providers/l10n_providers.dart';
import 'package:mangayomi/utils/riverpod.dart';
import 'package:mangayomi/modules/manga/reader/providers/push_router.dart';
import 'package:mangayomi/services/get_chapter_pages.dart';
import 'package:mangayomi/utils/extensions/build_context_extensions.dart';
import 'package:mangayomi/modules/manga/reader/u_chap_data_preload.dart';
import 'package:mangayomi/modules/manga/reader/providers/reader_controller_provider.dart';
import 'package:mangayomi/modules/manga/reader/widgets/circular_progress_indicator_animate_rotate.dart';
import 'package:mangayomi/modules/more/settings/reader/reader_screen.dart';
import 'package:mangayomi/modules/manga/reader/providers/manga_reader_provider.dart';
import 'package:mangayomi/modules/widgets/progress_center.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:window_manager/window_manager.dart';

typedef DoubleClickAnimationListener = void Function();

class _CanvasAnchor {
  const _CanvasAnchor({
    required this.pageData,
    required this.localOffset,
    required this.viewportPoint,
  });

  final UChapDataPreload pageData;
  final Offset localOffset;
  final Offset viewportPoint;
}

class MangaReaderView extends ConsumerStatefulWidget {
  final int chapterId;
  const MangaReaderView({super.key, required this.chapterId});

  @override
  ConsumerState<MangaReaderView> createState() => _MangaReaderViewState();
}

class _MangaReaderViewState extends ConsumerState<MangaReaderView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(mangaReaderProvider(widget.chapterId));
    });
  }

  @override
  Widget build(BuildContext context) {
    final chapterData = ref.watch(mangaReaderProvider(widget.chapterId));

    return chapterData.when(
      loading: () => scaffoldWith(context, const ProgressCenter()),
      error: (error, _) =>
          scaffoldWith(context, Center(child: Text(error.toString()))),
      data: (data) {
        final chapter = data.chapter;
        final model = data.pages;

        if (model.pageUrls.isEmpty &&
            !(chapter.manga.value?.isLocalArchive ?? false)) {
          return scaffoldWith(
            context,
            const Center(child: Text('Error: no pages available')),
            restoreUi: true,
          );
        }

        return MangaChapterPageGallery(
          chapter: chapter,
          chapterUrlModel: model,
        );
      },
    );
  }

  Widget scaffoldWith(
    BuildContext context,
    Widget body, {
    bool restoreUi = false,
  }) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(''),
        leading: BackButton(
          onPressed: () {
            if (restoreUi) {
              SystemChrome.setEnabledSystemUIMode(
                SystemUiMode.manual,
                overlays: SystemUiOverlay.values,
              );
            }
            Navigator.of(context).pop();
          },
        ),
      ),
      body: body,
    );
  }
}

class MangaChapterPageGalleryState {
  static void setNavigatingToChapter() {
    _MangaChapterPageGalleryState._isNavigatingToChapter = true;
  }
}

class MangaChapterPageGallery extends ConsumerStatefulWidget {
  const MangaChapterPageGallery({
    super.key,
    required this.chapter,
    required this.chapterUrlModel,
  });
  final GetChapterPagesModel chapterUrlModel;

  final Chapter chapter;

  @override
  ConsumerState createState() {
    return _MangaChapterPageGalleryState();
  }
}

class _MangaChapterPageGalleryState
    extends ConsumerState<MangaChapterPageGallery>
    with
        TickerProviderStateMixin,
        WidgetsBindingObserver,
        ReaderMemoryManagement,
        PageNavigationMixin {
  late AnimationController _scaleAnimationController;
  Animation<double>? _continuousScaleAnimation;
  Animation<Offset>? _continuousPanAnimation;
  VoidCallback? _continuousScaleAnimationListener;

  Ticker? _continuousFlingTicker;
  Duration? _continuousFlingLastTimestamp;
  Offset _continuousFlingVelocity = Offset.zero;

  Offset? _continuousVelocitySamplePosition;
  Duration? _continuousVelocitySampleTime;

  late ReaderController _readerController = ref.read(
    readerControllerProvider(chapter: chapter).notifier,
  );

  bool isDesktop = Platform.isMacOS || Platform.isLinux || Platform.isWindows;
  final ValueNotifier<bool> _isScrolling = ValueNotifier(false);
  Timer? _scrollIdleTimer;
  bool _firstLaunch = true;
  final Stopwatch _readingStopwatch = Stopwatch();

  /// Flag to prevent fullscreen from being disabled when navigating between
  /// chapters via pushReplacement. The old widget's dispose runs after the new
  /// widget is created, which would clobber the new reader's fullscreen state.
  static bool _isNavigatingToChapter = false;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _readingStopwatch.stop();
    _readerController.setMangaHistoryUpdate(
      readingTimeSeconds: _readingStopwatch.elapsed.inSeconds,
    );
    _rebuildDetail.close();
    _doubleClickAnimationController.dispose();
    if (_continuousScaleAnimationListener != null &&
        _continuousScaleAnimation != null) {
      _continuousScaleAnimation!.removeListener(
        _continuousScaleAnimationListener!,
      );
    }
    _scaleAnimationController.dispose();
    _failedToLoadImage.dispose();
    _autoScroll.value = false;
    _autoScroll.dispose();
    _autoScrollPage.dispose();
    _scrollIdleTimer?.cancel();
    _isScrolling.dispose();
    _itemPositionsListener.itemPositions.removeListener(_readProgressListener);
    _canvasCameraController.removeListener(_onCanvasCameraChanged);
    _canvasCameraController.dispose();
    _extendedController.dispose();
    clearGestureDetailsCache();
    if (_isNavigatingToChapter) {
      _isNavigatingToChapter = false;
    } else if (isDesktop) {
      setFullScreen(value: false);
    } else {
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
    discordRpc?.showIdleText();
    final actualIdx = _pageViewToActualIndex(_currentIndex!);
    final index = pages[actualIdx].index;
    if (index != null) {
      _readerController.setPageIndex(
        _isDoublePageActive ? index : _geCurrentIndex(index),
        true,
      );
    }
    disposePreloadManager();
    _readerController.keepAliveLink?.close();
    WakelockPlus.disable();
    _continuousFlingTicker?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _readingStopwatch.stop();
      final actualIdx = _pageViewToActualIndex(_currentIndex!);
      final index = pages[actualIdx].index;
      if (index != null) {
        _readerController.setPageIndex(
          _isDoublePageActive ? index : _geCurrentIndex(index),
          true,
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      _readingStopwatch.start();
    }
  }

  late final _autoScroll = ValueNotifier(
    _readerController.autoScrollValues().$1,
  );
  late final _autoScrollPage = ValueNotifier(_autoScroll.value);
  late GetChapterPagesModel _chapterUrlModel = widget.chapterUrlModel;

  late Chapter chapter = widget.chapter;

  final _failedToLoadImage = ValueNotifier<bool>(false);

  late int? _currentIndex = _readerController.getPageIndex();

  late final ItemScrollController _itemScrollController =
      ItemScrollController();
  final ScrollOffsetController _pageOffsetController = ScrollOffsetController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  late final ReaderCameraController _canvasCameraController =
      ReaderCameraController();
  ReaderScene _canvasScene = ReaderScene.empty;
  Size _canvasViewportSize = Size.zero;
  bool _canvasCameraInitialized = false;
  bool _canvasSceneSyncScheduled = false;
  bool _canvasRebuildScheduled = false;
  bool _canvasStateSyncScheduled = false;
  final List<VoidCallback> _pendingCanvasStateActions = [];
  _CanvasAnchor? _pendingCanvasAnchor;
  int? _canvasVisiblePageIndex;
  bool _canvasPageUpdateScheduled = false;
  int? _pendingCanvasPageIndex;
  bool _isCanvasSliderInteractionActive = false;
  int? _activeCanvasSliderChapterId;

  late AnimationController _doubleClickAnimationController;

  Animation<double>? _doubleClickAnimation;
  late DoubleClickAnimationListener _doubleClickAnimationListener;
  List<double> doubleTapScales = <double>[1.0, 2.0];
  final StreamController<double> _rebuildDetail =
      StreamController<double>.broadcast();
  static const double _continuousBaseScale = 1.0;
  static const double _continuousMinScale = 0.35;
  static const double _continuousMaxScale = 6.0;
  static const double _continuousDoubleTapScale = 2.0;
  static const double _continuousWheelZoomFactor = 0.12;

  @override
  void initState() {
    super.initState();
    _readingStopwatch.start();
    _doubleClickAnimationController = AnimationController(
      duration: _doubleTapAnimationDuration(),
      vsync: this,
    );
    _scaleAnimationController = AnimationController(
      duration: _continuousDoubleTapAnimationDuration(),
      vsync: this,
    );
    _itemPositionsListener.itemPositions.addListener(_readProgressListener);
    initPageNavigation(
      itemScrollController: _itemScrollController,
      extendedController: _extendedController,
    );
    _initCurrentIndex();
    discordRpc?.showChapterDetails(ref, chapter);
    WidgetsBinding.instance.addObserver(this);
    _initWakelock();
    _continuousFlingTicker = createTicker(_onContinuousFlingTick);
    _canvasCameraController.addListener(_onCanvasCameraChanged);
  }

  void _initWakelock() {
    final keepOn = isar.settings.getSync(227)!.keepScreenOnReader ?? true;
    if (keepOn) {
      WakelockPlus.enable();
    }
  }

  // final double _horizontalScaleValue = 1.0;
  bool _isNextChapterPreloading = false;
  bool _isPrevChapterPreloading = false;

  /// Guard flag: suppresses [_readProgressListener] during scroll position
  /// adjustment after prepending previous-chapter pages.
  bool _isAdjustingScroll = false;

  late int pagePreloadAmount = ref.read(pagePreloadAmountStateProvider);
  late bool _isBookmarked = _readerController.getChapterBookmarked();

  bool _isLastPageTransition = false;
  final _currentReaderMode = StateProvider<ReaderMode?>(() => null);
  PageMode? _pageMode;
  bool _isView = false;
  double _continuousScale = _continuousBaseScale;
  double _continuousGestureStartScale = _continuousBaseScale;
  Offset _continuousGestureStartPan = Offset.zero;
  double _continuousPinchStartDistance = 0;
  Offset _continuousPinchStartFocalPoint = Offset.zero;
  Offset _continuousLastSinglePointerPosition = Offset.zero;
  Offset _continuousPanOffset = Offset.zero;
  int _continuousPointerCount = 0;
  bool _desktopZoomModifierPressed = false;
  bool _continuousScrollFrameScheduled = false;
  double _continuousQueuedScrollDelta = 0;
  final Map<int, Offset> _continuousActivePointers = {};
  final List<int> _cropBorderCheckList = [];
  final GlobalKey _continuousCanvasKey = GlobalKey();

  late final _extendedController = ExtendedPageController(
    initialPage: _currentIndex!,
  );

  Axis _scrollDirection = Axis.vertical;
  bool _isReverseHorizontal = false;

  Color _backgroundColor(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.9);

  bool _usesCanvasEngine(ReaderMode? readerMode) {
    if (readerMode == null) {
      return false;
    }
    final normalizedMode = normalizeReaderMode(readerMode);
    return normalizedMode == ReaderMode.webtoon ||
        normalizedMode == ReaderMode.verticalContinuous;
  }

  ReaderCanvasModeConfig _canvasModeConfig(
    ReaderMode readerMode, {
    double viewportWidth = 0,
  }) {
    final showPageGaps = ref.read(showPageGapsStateProvider);
    final sidePaddingPercent = ref.read(webtoonSidePaddingStateProvider);
    final sidePadding = viewportWidth * sidePaddingPercent / 100;
    return ReaderCanvasModeConfig.fromReaderMode(
      readerMode,
      longStripGap: showPageGaps ? 6 : 0,
      longStripSidePadding: sidePadding,
    );
  }

  ReaderScene _buildSceneForCurrentReaderMode({
    required List<UChapDataPreload> readerPages,
    required ReaderMode readerMode,
    required Size viewportSize,
  }) {
    final config = _canvasModeConfig(
      readerMode,
      viewportWidth: viewportSize.width,
    );
    return config.sceneBuilder.build(
      pages: readerPages,
      viewportSize: viewportSize,
      settings: config.sceneSettings,
    );
  }

  ReaderScenePage? _nearestCanvasPageForWorldPoint(Offset worldPoint) {
    if (_canvasScene.pages.isEmpty) {
      return null;
    }

    for (final page in _canvasScene.pages) {
      if (page.worldRect.contains(worldPoint)) {
        return page;
      }
    }

    ReaderScenePage? nearestPage;
    var nearestDistance = double.infinity;
    for (final page in _canvasScene.pages) {
      final distance = (page.worldRect.center - worldPoint).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPage = page;
      }
    }
    return nearestPage;
  }

  ReaderScenePage? _nearestCanvasContentPageForWorldPoint(Offset worldPoint) {
    ReaderScenePage? nearestPage;
    var nearestDistance = double.infinity;
    for (final page in _canvasScene.pages) {
      if (page.isTransitionPage) {
        continue;
      }
      if (page.worldRect.contains(worldPoint)) {
        return page;
      }
      final distance = (page.worldRect.center - worldPoint).distanceSquared;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestPage = page;
      }
    }
    return nearestPage;
  }

  ReaderScenePage? _primaryCanvasContentPage(Rect visibleWorldRect) {
    if (_canvasScene.pages.isEmpty) {
      return null;
    }

    ReaderScenePage? bestPage;
    var bestOverlapArea = -1.0;
    for (final page in _canvasScene.pages) {
      if (page.isTransitionPage) {
        continue;
      }
      final overlap = page.worldRect.intersect(visibleWorldRect);
      final overlapArea = overlap.isEmpty ? 0.0 : overlap.width * overlap.height;
      if (overlapArea > bestOverlapArea) {
        bestOverlapArea = overlapArea;
        bestPage = page;
      }
    }

    if (bestPage != null && bestOverlapArea > 0) {
      return bestPage;
    }

    return _nearestCanvasContentPageForWorldPoint(visibleWorldRect.center);
  }

  int? _findCanvasScenePageIndex({
    required int chapterId,
    required int chapterPageIndex,
  }) {
    for (final page in _canvasScene.pages) {
      final data = page.data;
      if (data is! UChapDataPreload || page.isTransitionPage) {
        continue;
      }
      if (data.chapter?.id == chapterId && data.index == chapterPageIndex) {
        return page.pageIndex;
      }
    }
    return null;
  }

  void _scheduleCanvasStateSync(VoidCallback action) {
    if (!mounted) {
      return;
    }
    _pendingCanvasStateActions.add(action);
    if (_canvasStateSyncScheduled) {
      return;
    }
    _canvasStateSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canvasStateSyncScheduled = false;
      if (!mounted) {
        _pendingCanvasStateActions.clear();
        return;
      }
      final actions = List<VoidCallback>.from(_pendingCanvasStateActions);
      _pendingCanvasStateActions.clear();
      for (final pendingAction in actions) {
        if (!mounted) {
          break;
        }
        pendingAction();
      }
    });
  }

  void _markCanvasInteractionActive() {
    if (!_isScrolling.value) {
      _isScrolling.value = true;
    }
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) {
        _isScrolling.value = false;
      }
    });
  }

  void _onCanvasCameraChanged() {
    if (!_usesCanvasEngine(ref.read(_currentReaderMode)) ||
        _canvasScene.pages.isEmpty ||
        _canvasViewportSize.isEmpty ||
        _isCanvasSliderInteractionActive) {
      return;
    }

    final visibleWorldRect = _canvasCameraController.visibleWorldRect(
      _canvasViewportSize,
    );
    final currentPage = _primaryCanvasContentPage(visibleWorldRect);
    if (currentPage == null || currentPage.pageIndex == _canvasVisiblePageIndex) {
      return;
    }
    _pendingCanvasPageIndex = currentPage.pageIndex;
    if (_canvasPageUpdateScheduled) {
      return;
    }
    _canvasPageUpdateScheduled = true;
    _scheduleCanvasStateSync(() {
      _canvasPageUpdateScheduled = false;
      final pageIndex = _pendingCanvasPageIndex;
      _pendingCanvasPageIndex = null;
      if (!mounted || pageIndex == null) {
        return;
      }
      _markCanvasInteractionActive();
      if (pageIndex == _canvasVisiblePageIndex) {
        return;
      }
      _canvasVisiblePageIndex = pageIndex;
      unawaited(_onPageChanged(pageIndex));
    });
  }

  void _scheduleCanvasSceneSync({
    required ReaderScene scene,
    required Size viewportSize,
  }) {
    _canvasScene = scene;
    _canvasViewportSize = viewportSize;
    if (_canvasSceneSyncScheduled) {
      return;
    }
    _canvasSceneSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _canvasSceneSyncScheduled = false;
      if (!mounted || _canvasViewportSize.isEmpty || _canvasScene.pages.isEmpty) {
        return;
      }
      if (!_canvasCameraInitialized) {
        _initializeCanvasCamera();
      } else {
        _applyPendingCanvasAnchorIfNeeded();
      }
      _onCanvasCameraChanged();
    });
  }

  void _scheduleCanvasSceneRebuild({bool preserveAnchor = true}) {
    if (!_usesCanvasEngine(ref.read(_currentReaderMode)) || !mounted) {
      return;
    }
    if (preserveAnchor && _pendingCanvasAnchor == null) {
      _pendingCanvasAnchor = _captureCanvasAnchor();
    }
    if (_canvasRebuildScheduled) {
      return;
    }
    _canvasRebuildScheduled = true;
    _scheduleCanvasStateSync(() {
      _canvasRebuildScheduled = false;
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  void _initializeCanvasCamera() {
    if (_canvasScene.pages.isEmpty || _canvasViewportSize.isEmpty) {
      return;
    }
    final savedChapterIndex = _readerController.getPageIndex();
    var targetPage = _canvasScene.pages.firstWhere(
      (page) =>
          (page.data as UChapDataPreload).chapter?.id == chapter.id &&
          (page.data as UChapDataPreload).index == savedChapterIndex,
      orElse: () => _canvasScene.pages.first,
    );
    final translation = Offset(
      0,
      -targetPage.worldRect.top,
    );
    _canvasCameraController.setScale(1);
    _canvasCameraController.setTranslation(translation);
    _canvasCameraInitialized = true;
  }

  void _applyPendingCanvasAnchorIfNeeded() {
    final anchor = _pendingCanvasAnchor;
    if (anchor == null) {
      return;
    }

    final targetPage = _canvasScene.pages.firstWhere(
      (page) => identical(page.data, anchor.pageData),
      orElse: () => _canvasScene.pages.first,
    );
    final targetWorldPoint = targetPage.worldRect.topLeft + anchor.localOffset;
    final scale = _canvasCameraController.state.scale;
    final translation = anchor.viewportPoint - targetWorldPoint * scale;
    _pendingCanvasAnchor = null;
    _canvasCameraController.setTranslation(translation);
  }

  _CanvasAnchor? _captureCanvasAnchor() {
    if (_canvasScene.pages.isEmpty || _canvasViewportSize.isEmpty) {
      return null;
    }
    final viewportPoint = _canvasViewportSize.center(Offset.zero);
    final worldPoint = _canvasCameraController.viewportToWorld(viewportPoint);
    final page = _nearestCanvasPageForWorldPoint(worldPoint);
    if (page == null || page.data is! UChapDataPreload) {
      return null;
    }
    return _CanvasAnchor(
      pageData: page.data! as UChapDataPreload,
      localOffset: worldPoint - page.worldRect.topLeft,
      viewportPoint: viewportPoint,
    );
  }

  void _jumpToCanvasPageIndex(int pageIndex, {bool animate = true}) {
    if (_canvasScene.pages.isEmpty ||
        pageIndex < 0 ||
        pageIndex >= _canvasScene.pages.length) {
      return;
    }
    final targetRect = _canvasScene.pages[pageIndex].worldRect;
    final translation = Offset(0, -targetRect.top);
    if (animate) {
      _canvasCameraController.animateTo(translation: translation);
    } else {
      _canvasCameraController.setTranslation(translation);
    }
  }

  void _beginCanvasSliderInteraction() {
    if (!_usesCanvasEngine(ref.read(_currentReaderMode))) {
      return;
    }
    _canvasCameraController.stopMotion();
    _isCanvasSliderInteractionActive = true;
    _activeCanvasSliderChapterId = chapter.id;
  }

  void _endCanvasSliderInteraction() {
    _isCanvasSliderInteractionActive = false;
    _activeCanvasSliderChapterId = null;
  }

  void _navigateCanvasPage({required bool forward}) {
    if (_canvasScene.pages.isEmpty) {
      return;
    }
    final currentIndex = _canvasVisiblePageIndex ?? _currentIndex ?? 0;
    final snapPolicy = const LongStripNavigationPolicy();
    final targetRect = forward
        ? snapPolicy.targetPageRectForNext(
            scene: _canvasScene,
            currentPageIndex: currentIndex,
          )
        : snapPolicy.targetPageRectForPrevious(
            scene: _canvasScene,
            currentPageIndex: currentIndex,
          );
    if (targetRect == null) {
      return;
    }
    final targetPage = _canvasScene.pages.firstWhere(
      (page) => page.worldRect == targetRect,
    );
    _jumpToCanvasPageIndex(targetPage.pageIndex);
  }

  double _currentContinuousScale() {
    final scale = _continuousScale;
    if (!scale.isFinite || scale == 0) {
      return _continuousBaseScale;
    }
    return scale;
  }

  double _clampContinuousScale(double scale) {
    return math.max(_continuousMinScale, math.min(_continuousMaxScale, scale));
  }

  RenderBox? _continuousCanvasRenderBox() {
    final renderObject =
        _continuousCanvasKey.currentContext?.findRenderObject() ??
        context.findRenderObject();
    if (renderObject is! RenderBox) {
      return null;
    }
    return renderObject;
  }

  Offset _readerViewportCenter() {
    final renderObject = _continuousCanvasRenderBox();
    if (renderObject == null) {
      final viewport = MediaQuery.sizeOf(context);
      return Offset(viewport.width / 2, viewport.height / 2);
    }
    return Offset(renderObject.size.width / 2, renderObject.size.height / 2);
  }

  Offset _readerLocalPointFromGlobal(Offset globalPoint) {
    final renderObject = _continuousCanvasRenderBox();
    if (renderObject == null) {
      return _readerViewportCenter();
    }
    return renderObject.globalToLocal(globalPoint);
  }

  Offset _panForScaleChange({
    required double fromScale,
    required double toScale,
    required Offset currentPan,
    required Offset localFocalPoint,
  }) {
    final safeFromScale = fromScale == 0 ? _continuousBaseScale : fromScale;
    final ratio = toScale / safeFromScale;
    final focalFromCenter = localFocalPoint - _readerViewportCenter();
    final scaledPan = Offset(
      focalFromCenter.dx + (currentPan.dx - focalFromCenter.dx) * ratio,
      focalFromCenter.dy + (currentPan.dy - focalFromCenter.dy) * ratio,
    );
    return _clampContinuousPan(scaledPan, scale: toScale);
  }

  Offset _clampContinuousPan(Offset offset, {double? scale}) {
    final currentScale = scale ?? _currentContinuousScale();
    if (currentScale <= _continuousBaseScale + 0.01 || !mounted) {
      return Offset.zero;
    }

    final renderObject = _continuousCanvasRenderBox();
    final viewport = renderObject?.size ?? MediaQuery.sizeOf(context);
    final maxDx = math.max(
      0.0,
      (viewport.width * currentScale - viewport.width) / 2,
    );
    final maxDy = math.max(
      0.0,
      (viewport.height * currentScale - viewport.height) / 2,
    );
    return Offset(
      offset.dx.clamp(-maxDx, maxDx).toDouble(),
      offset.dy.clamp(-maxDy, maxDy).toDouble(),
    );
  }

  ScrollPhysics _continuousScrollPhysics() {
    if ((isDesktop && _desktopZoomModifierPressed) ||
        _currentContinuousScale() > _continuousBaseScale + 0.01 ||
        _continuousPointerCount >= 2) {
      return const NeverScrollableScrollPhysics();
    }
    return const ClampingScrollPhysics();
  }

  void _setContinuousScale(double targetScale, {Offset? localFocalPoint}) {
    final clamped = _clampContinuousScale(targetScale);
    final nextPan = localFocalPoint == null
        ? _clampContinuousPan(_continuousPanOffset, scale: clamped)
        : _panForScaleChange(
            fromScale: _continuousScale,
            toScale: clamped,
            currentPan: _continuousPanOffset,
            localFocalPoint: localFocalPoint,
          );
    if ((_continuousScale - clamped).abs() < 0.001 &&
        (_continuousPanOffset - nextPan).distance < 0.001) {
      return;
    }
    setState(() {
      _continuousScale = clamped;
      _continuousPanOffset = nextPan;
    });
  }

  void _setContinuousPan(Offset offset) {
    final clamped = _clampContinuousPan(offset);
    if ((_continuousPanOffset - clamped).distance < 0.001) {
      return;
    }
    setState(() {
      _continuousPanOffset = clamped;
    });
  }

  void _queueContinuousScrollDelta(double delta) {
    if (delta.abs() < 0.01) {
      return;
    }
    _continuousQueuedScrollDelta += delta;
    if (_continuousScrollFrameScheduled) {
      return;
    }
    _continuousScrollFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _continuousScrollFrameScheduled = false;
      final queuedDelta = _continuousQueuedScrollDelta;
      _continuousQueuedScrollDelta = 0;
      if (!mounted || queuedDelta.abs() < 0.01) {
        return;
      }
      unawaited(
        _pageOffsetController.animateScroll(
          offset: queuedDelta,
          duration: const Duration(milliseconds: 16),
          curve: Curves.linear,
        ),
      );
    });
  }

  void _applyContinuousDragDelta(Offset delta) {
    final readerMode = ref.read(_currentReaderMode)!;
    final isHorizontalContinuous =
        readerMode == ReaderMode.horizontalContinuous ||
        readerMode == ReaderMode.horizontalContinuousRTL;

    final scrollDirectionFactor =
        readerMode == ReaderMode.horizontalContinuousRTL ? 1.0 : -1.0;

    final currentPan = _continuousPanOffset;
    final desiredPan = _clampContinuousPan(currentPan + delta);

    final consumed = desiredPan - currentPan;
    final leftover = delta - consumed;

    if (consumed.distance >= 0.001) {
      setState(() {
        _continuousPanOffset = desiredPan;
      });
    }

    final mainAxisLeftover = isHorizontalContinuous ? leftover.dx : leftover.dy;

    if (mainAxisLeftover.abs() >= 0.001) {
      _queueContinuousScrollDelta(mainAxisLeftover * scrollDirectionFactor);
    }
  }

  void _animateContinuousScale(double targetScale, {Offset? localFocalPoint}) {
    if (_continuousScaleAnimationListener != null &&
        _continuousScaleAnimation != null) {
      _continuousScaleAnimation!.removeListener(
        _continuousScaleAnimationListener!,
      );
    }

    _scaleAnimationController
      ..stop()
      ..reset();

    _continuousScaleAnimation =
        Tween<double>(
          begin: _continuousScale,
          end: _clampContinuousScale(targetScale),
        ).animate(
          CurvedAnimation(
            curve: Curves.easeOutCubic,
            parent: _scaleAnimationController,
          ),
        );
    final targetPan = localFocalPoint == null
        ? _clampContinuousPan(_continuousPanOffset, scale: targetScale)
        : _panForScaleChange(
            fromScale: _continuousScale,
            toScale: _clampContinuousScale(targetScale),
            currentPan: _continuousPanOffset,
            localFocalPoint: localFocalPoint,
          );
    _continuousPanAnimation =
        Tween<Offset>(begin: _continuousPanOffset, end: targetPan).animate(
          CurvedAnimation(
            curve: Curves.easeOutCubic,
            parent: _scaleAnimationController,
          ),
        );
    _continuousScaleAnimationListener = () {
      if (!mounted) {
        return;
      }
      final nextScale = _continuousScaleAnimation!.value;
      setState(() {
        _continuousScale = nextScale;
        _continuousPanOffset = nextScale <= _continuousBaseScale + 0.01
            ? Offset.zero
            : _clampContinuousPan(
                _continuousPanAnimation?.value ?? _continuousPanOffset,
                scale: nextScale,
              );
      });
    };
    _continuousScaleAnimation!.addListener(_continuousScaleAnimationListener!);
    _scaleAnimationController.forward();
  }

  void _handleContinuousPointerSignal(PointerSignalEvent event) {
    if (!_isContinuousMode() || event is! PointerScrollEvent) {
      return;
    }

    final hardwareKeyboard = HardwareKeyboard.instance;
    final wantsZoom =
        hardwareKeyboard.isControlPressed || hardwareKeyboard.isMetaPressed;
    if (isDesktop && wantsZoom != _desktopZoomModifierPressed && mounted) {
      setState(() {
        _desktopZoomModifierPressed = wantsZoom;
      });
    }
    if (!wantsZoom) {
      return;
    }

    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final scrollEvent = resolved as PointerScrollEvent;
      final delta = scrollEvent.scrollDelta.dy == 0
          ? scrollEvent.scrollDelta.dx
          : scrollEvent.scrollDelta.dy;
      if (delta == 0) {
        return;
      }

      final currentScale = _currentContinuousScale();
      final zoomFactor = delta > 0
          ? 1 - _continuousWheelZoomFactor
          : 1 + _continuousWheelZoomFactor;
      final nextScale = _clampContinuousScale(currentScale * zoomFactor);
      _scaleAnimationController.stop();
      _setContinuousScale(
        nextScale,
        localFocalPoint: _readerLocalPointFromGlobal(scrollEvent.position),
      );
    });
  }

  Duration _continuousDoubleTapAnimationDuration() {
    if (isDesktop) {
      return const Duration(milliseconds: 210);
    }
    return const Duration(milliseconds: 150);
  }

  void _onContinuousPointerDown(PointerDownEvent event) {
    if (!_isContinuousMode()) {
      return;
    }
    _stopContinuousFling();
    _continuousActivePointers[event.pointer] = event.localPosition;
    _continuousLastSinglePointerPosition = event.localPosition;
    if (_continuousActivePointers.length >= 2) {
      final points = _continuousActivePointers.values.take(2).toList();
      _scaleAnimationController.stop();
      _continuousGestureStartScale = _currentContinuousScale();
      _continuousGestureStartPan = _continuousPanOffset;
      _continuousPinchStartDistance = (points[0] - points[1]).distance;
      _continuousPinchStartFocalPoint = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
    }
    setState(() {
      _continuousPointerCount = _continuousActivePointers.length;
    });
  }

  void _updateContinuousDragVelocity(Offset position, Duration timeStamp) {
    final lastPosition = _continuousVelocitySamplePosition;
    final lastTime = _continuousVelocitySampleTime;

    _continuousVelocitySamplePosition = position;
    _continuousVelocitySampleTime = timeStamp;

    if (lastPosition == null || lastTime == null) return;

    final dt = (timeStamp - lastTime).inMicroseconds;
    if (dt <= 0) return;

    final dtSeconds = dt / 1e6;
    final v = (position - lastPosition) / dtSeconds;

    _continuousFlingVelocity = Offset(
      _continuousFlingVelocity.dx * 0.75 + v.dx * 0.25,
      _continuousFlingVelocity.dy * 0.75 + v.dy * 0.25,
    );
  }

  void _onContinuousPointerMove(PointerMoveEvent event) {
    if (!_isContinuousMode()) {
      return;
    }
    _continuousActivePointers[event.pointer] = event.localPosition;

    if (_continuousActivePointers.length >= 2) {
      _continuousFlingVelocity = Offset.zero;
      final points = _continuousActivePointers.values.take(2).toList();
      final currentDistance = (points[0] - points[1]).distance;
      if (_continuousPinchStartDistance <= 0.0 || currentDistance <= 0.0) {
        return;
      }
      final focalPoint = Offset(
        (points[0].dx + points[1].dx) / 2,
        (points[0].dy + points[1].dy) / 2,
      );
      final nextScale = _clampContinuousScale(
        _continuousGestureStartScale *
            (currentDistance / _continuousPinchStartDistance),
      );
      final nextPan = _clampContinuousPan(
        _panForScaleChange(
              fromScale: _continuousGestureStartScale,
              toScale: nextScale,
              currentPan: _continuousGestureStartPan,
              localFocalPoint: _continuousPinchStartFocalPoint,
            ) +
            (focalPoint - _continuousPinchStartFocalPoint),
        scale: nextScale,
      );
      setState(() {
        _continuousScale = nextScale;
        _continuousPanOffset = nextPan;
      });
      return;
    }

    if (_currentContinuousScale() > _continuousBaseScale + 0.01 &&
        (!isDesktop || event.buttons != 0)) {
      final delta = event.localPosition - _continuousLastSinglePointerPosition;
      _continuousLastSinglePointerPosition = event.localPosition;
      _updateContinuousDragVelocity(event.localPosition, event.timeStamp);
      _applyContinuousDragDelta(delta);
    }
  }

  void _onContinuousPointerUp(PointerEvent event) {
    if (!_isContinuousMode()) {
      return;
    }

    _continuousActivePointers.remove(event.pointer);

    setState(() {
      _continuousPointerCount = _continuousActivePointers.length;
    });

    if (_continuousActivePointers.length == 1) {
      _continuousLastSinglePointerPosition =
          _continuousActivePointers.values.first;

      _continuousVelocitySamplePosition = _continuousLastSinglePointerPosition;
      _continuousVelocitySampleTime = event.timeStamp;
    } else if (_continuousActivePointers.isEmpty) {
      final velocity = _continuousFlingVelocity;

      _continuousVelocitySamplePosition = null;
      _continuousVelocitySampleTime = null;

      _startContinuousFling(velocity);
    }

    if (_currentContinuousScale() <= _continuousBaseScale + 0.01) {
      _setContinuousPan(Offset.zero);
    }
  }

  void _startContinuousFling(Offset velocity) {
    if (velocity.distance < 50.0) return;

    _continuousFlingVelocity = velocity;
    _continuousFlingLastTimestamp = null;
    _continuousFlingTicker?.start();
  }

  void _stopContinuousFling() {
    _continuousFlingTicker?.stop();
    _continuousFlingLastTimestamp = null;
    _continuousFlingVelocity = Offset.zero;
  }

  void _onContinuousFlingTick(Duration elapsed) {
    if (!mounted) {
      _stopContinuousFling();
      return;
    }

    final last = _continuousFlingLastTimestamp;
    _continuousFlingLastTimestamp = elapsed;

    if (last == null) return;

    final dtMicros = (elapsed - last).inMicroseconds;
    if (dtMicros <= 0) return;

    final dt = dtMicros / 1e6;

    final delta = _continuousFlingVelocity * dt;

    if (delta.distance >= 0.001) {
      _applyContinuousDragDelta(delta);
    }

    final decay = math.pow(0.92, dt * 60.0).toDouble();

    _continuousFlingVelocity = Offset(
      _continuousFlingVelocity.dx * decay,
      _continuousFlingVelocity.dy * decay,
    );

    if (_continuousFlingVelocity.distance < 20.0) {
      _stopContinuousFling();
    }
  }

  void _onContinuousPointerCancel(PointerCancelEvent event) {
    _onContinuousPointerUp(event);
  }

  double _continuousStepExtent(ReaderMode readerMode) {
    final viewport = MediaQuery.sizeOf(context);
    final isHorizontalContinuous =
        readerMode == ReaderMode.horizontalContinuous ||
        readerMode == ReaderMode.horizontalContinuousRTL;
    final mainAxisExtent = isHorizontalContinuous
        ? viewport.width
        : viewport.height;
    return mainAxisExtent * 0.9;
  }

  void _navigateContinuousStep({
    required ReaderMode readerMode,
    required bool forward,
  }) {
    final isHorizontalContinuous =
        readerMode == ReaderMode.horizontalContinuous ||
        readerMode == ReaderMode.horizontalContinuousRTL;
    final directionMultiplier = readerMode == ReaderMode.horizontalContinuousRTL
        ? -1.0
        : 1.0;
    final signedOffset =
        _continuousStepExtent(readerMode) *
        (forward ? 1.0 : -1.0) *
        (isHorizontalContinuous ? directionMultiplier : 1.0);
    _pageOffsetController.animateScroll(
      offset: signedOffset,
      duration: const Duration(milliseconds: 180),
    );
  }

  void _goPreviousInReader(ReaderMode readerMode) {
    if (_usesCanvasEngine(readerMode)) {
      _navigateCanvasPage(forward: false);
      return;
    }
    if (_isContinuousMode()) {
      _navigateContinuousStep(readerMode: readerMode, forward: false);
      return;
    }
    navigationService.previousPage(
      readerMode: readerMode,
      currentIndex: _currentIndex!,
      animate: true,
    );
  }

  void _goNextInReader(ReaderMode readerMode) {
    if (_usesCanvasEngine(readerMode)) {
      _navigateCanvasPage(forward: true);
      return;
    }
    if (_isContinuousMode()) {
      _navigateContinuousStep(readerMode: readerMode, forward: true);
      return;
    }
    navigationService.nextPage(
      readerMode: readerMode,
      currentIndex: _currentIndex!,
      maxPages: _pageViewPageCount,
      animate: true,
    );
  }

  void _onReaderObservedKeyEvent(KeyEvent event) {
    final pressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    if (pressed == _desktopZoomModifierPressed) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _desktopZoomModifierPressed = pressed;
    });
  }

  double _readerAppBarHeight(bool fullScreenReader) {
    if (!_isView) {
      return 0;
    }
    if (Platform.isIOS) {
      return 120.0;
    }
    return !fullScreenReader && !isDesktop ? 55.0 : 80.0;
  }

  bool _isPointerOverReaderChrome(
    Offset globalPosition,
    bool fullScreenReader,
  ) {
    if (!_isView) {
      return false;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) {
      return false;
    }
    final local = renderObject.globalToLocal(globalPosition);
    final screenHeight = renderObject.size.height;
    final appBarHeight = _readerAppBarHeight(fullScreenReader);
    const bottomBarHeight = 130.0;

    return local.dy <= appBarHeight ||
        local.dy >= screenHeight - bottomBarHeight;
  }

  void _handleContinuousCanvasPointerSignal(
    PointerSignalEvent event,
    bool fullScreenReader,
  ) {
    if (event is PointerScrollEvent &&
        _isPointerOverReaderChrome(event.position, fullScreenReader)) {
      return;
    }
    _handleContinuousPointerSignal(event);
  }

  void _setFullScreen({bool? value}) async {
    if (isDesktop) {
      value = await windowManager.isFullScreen();
      setFullScreen(value: !value);
    }
    ref.read(fullScreenReaderStateProvider.notifier).set(!value!);
  }

  Widget _buildCanvasReader({
    required ReaderMode readerMode,
    required BackgroundColor backgroundColor,
    required bool fullScreenReader,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportSize = Size(constraints.maxWidth, constraints.maxHeight);
        final scene = _buildSceneForCurrentReaderMode(
          readerPages: pages,
          readerMode: readerMode,
          viewportSize: viewportSize,
        );
        _scheduleCanvasSceneSync(scene: scene, viewportSize: viewportSize);

        return Material(
          color: getBackgroundColor(backgroundColor),
          shadowColor: getBackgroundColor(backgroundColor),
          child: CanvasReaderView(
            scene: scene,
            cameraController: _canvasCameraController,
            backgroundColor: getBackgroundColor(backgroundColor),
            preloadMargin: pagePreloadAmount * context.height(1),
            snapPolicy: null,
            onTap: _isViewFunction,
            pageBuilder: (context, page, viewportRect) {
              final data = page.data as UChapDataPreload;
              if (data.isTransitionPage) {
                return SizedBox.expand(
                  child: TransitionViewVertical(data: data, fillParent: true),
                );
              }

              return SizedBox.expand(
                child: ImageViewVertical(
                  data: data,
                  failedToLoadImage: (value) {
                    _scheduleCanvasStateSync(() {
                      if (_failedToLoadImage.value != value && mounted) {
                        _failedToLoadImage.value = value;
                      }
                    });
                  },
                  onLongPressData: (pageData) => ImageActionsDialog.show(
                    context: context,
                    data: pageData,
                    manga: widget.chapter.manga.value!,
                    chapterName: pageData.chapter?.name ?? widget.chapter.name!,
                  ),
                  isHorizontal: false,
                  isScrolling: _isScrolling,
                  fillParent: true,
                  onMetricsChanged: () {
                    _scheduleCanvasSceneRebuild();
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = ref.watch(backgroundColorStateProvider);
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    final readerMode = ref.watch(_currentReaderMode);
    final bool isHorizontalContinuous = false;
    final useCanvasEngine = _usesCanvasEngine(readerMode);

    final l10n = l10nLocalizations(context)!;
    return ReaderKeyboardHandler(
      onObservedKeyEvent: _onReaderObservedKeyEvent,
      onPreviousPage: () => _goPreviousInReader(readerMode!),
      onNextPage: () => _goNextInReader(readerMode!),
      onEscape: () => _goBack(context),
      onFullScreen: () => _setFullScreen(),
      onNextChapter: () {
        bool hasNextChapter = _readerController.getChapterIndex().$1 != 0;
        if (hasNextChapter) {
          _isNavigatingToChapter = true;
          pushReplacementMangaReaderView(
            context: context,
            chapter: _readerController.getNextChapter(),
          );
        }
      },
      onPreviousChapter: () {
        bool hasPrevChapter =
            _readerController.getChapterIndex().$1 + 1 !=
            _readerController.getChaptersLength(
              _readerController.getChapterIndex().$2,
            );
        if (hasPrevChapter) {
          _isNavigatingToChapter = true;
          pushReplacementMangaReaderView(
            context: context,
            chapter: _readerController.getPrevChapter(),
          );
        }
      },
    ).wrapWithKeyboardListener(
      isReverseHorizontal: _isReverseHorizontal,
      child: NotificationListener<UserScrollNotification>(
        onNotification: (notification) {
          if (notification.direction == ScrollDirection.idle) {
            if (_isView) {
              _isViewFunction();
            }
          }

          return true;
        },
        child: Material(
          child: SafeArea(
            top: !fullScreenReader,
            bottom: false,
            child: ValueListenableBuilder(
              valueListenable: _failedToLoadImage,
              builder: (context, failedToLoadImage, child) {
                return Stack(
                  children: [
                    useCanvasEngine
                        ? _buildCanvasReader(
                            readerMode: readerMode!,
                            backgroundColor: backgroundColor,
                            fullScreenReader: fullScreenReader,
                          )
                        : _isContinuousMode()
                        ? ImageViewWebtoon(
                            pages: pages,
                            itemScrollController: _itemScrollController,
                            scrollOffsetController: _pageOffsetController,
                            itemPositionsListener: _itemPositionsListener,
                            scrollDirection: Axis.vertical,
                            minCacheExtent:
                                pagePreloadAmount * context.height(1),
                            initialScrollIndex: _readerController
                                .getPageIndex(),
                            physics: _continuousScrollPhysics(),
                            onLongPressData: (data) => ImageActionsDialog.show(
                              context: context,
                              data: data,
                              manga: widget.chapter.manga.value!,
                              chapterName: widget.chapter.name!,
                            ),
                            onFailedToLoadImage: (value) {
                              if (_failedToLoadImage.value != value && mounted) {
                                _failedToLoadImage.value = value;
                              }
                            },
                            backgroundColor: backgroundColor,
                            isDoublePageMode:
                                _pageMode == PageMode.doublePage &&
                                !isHorizontalContinuous,
                            isHorizontalContinuous: isHorizontalContinuous,
                            readerMode: ref.watch(_currentReaderMode)!,
                            containerKey: _continuousCanvasKey,
                            scale: _continuousScale,
                            panOffset: _continuousPanOffset,
                            onPointerSignal: (PointerSignalEvent event) =>
                                _handleContinuousCanvasPointerSignal(
                                  event,
                                  fullScreenReader,
                                ),
                            onPointerDown: _onContinuousPointerDown,
                            onPointerMove: _onContinuousPointerMove,
                            onPointerUp: _onContinuousPointerUp,
                            onPointerCancel: _onContinuousPointerCancel,
                            onDoubleTapDown: (offset) => _toggleScale(offset),
                            onDoubleTap: () {},
                            webtoonSidePadding: ref.watch(
                              webtoonSidePaddingStateProvider,
                            ),
                            showPageGaps: ref.watch(showPageGapsStateProvider),
                            reverse: _isReverseHorizontal,
                            isScrolling: _isScrolling,
                          )
                        : Material(
                            color: getBackgroundColor(backgroundColor),
                            shadowColor: getBackgroundColor(backgroundColor),
                            child:
                                (_pageMode == PageMode.doublePage &&
                                    !isHorizontalContinuous)
                                ? ExtendedImageGesturePageView.builder(
                                    controller: _extendedController,
                                    scrollDirection: _scrollDirection,
                                    reverse: _isReverseHorizontal,
                                    physics: const ClampingScrollPhysics(),
                                    canScrollPage: (_) {
                                      return true;
                                    },
                                    itemBuilder: (context, index) {
                                      int index1 = index * 2;
                                      int index2 = index1 + 1;
                                      final pageList = [
                                        index1 < pages.length
                                            ? pages[index1]
                                            : null,
                                        index2 < pages.length
                                            ? pages[index2]
                                            : null,
                                      ];
                                      return DoublePageView.paged(
                                        pages: _isReverseHorizontal
                                            ? pageList.reversed.toList()
                                            : pageList,
                                        backgroundColor: backgroundColor,
                                        onFailedToLoadImage: (val) {
                                          if (_failedToLoadImage.value != val &&
                                              mounted) {
                                            _failedToLoadImage.value = val;
                                          }
                                        },
                                        onLongPressData: (datas) {
                                          ImageActionsDialog.show(
                                            context: context,
                                            data: datas,
                                            manga: widget.chapter.manga.value!,
                                            chapterName: widget.chapter.name!,
                                          );
                                        },
                                      );
                                    },
                                    itemCount: (pages.length / 2).ceil(),
                                    onPageChanged: _onPageChanged,
                                  )
                                : ExtendedImageGesturePageView.builder(
                                    controller: _extendedController,
                                    scrollDirection: _scrollDirection,
                                    reverse: _isReverseHorizontal,
                                    physics: const ClampingScrollPhysics(),
                                    canScrollPage: (gestureDetails) {
                                      return true;
                                    },
                                    itemBuilder: (BuildContext context, int index) {
                                      if (pages[index].isTransitionPage) {
                                        return TransitionViewPaged(
                                          data: pages[index],
                                        );
                                      }

                                      return ImageViewPaged(
                                        data: pages[index],
                                        loadStateChanged: (state) {
                                          if (state.extendedImageLoadState ==
                                              LoadState.loading) {
                                            final ImageChunkEvent?
                                            loadingProgress =
                                                state.loadingProgress;
                                            final double progress =
                                                loadingProgress
                                                        ?.expectedTotalBytes !=
                                                    null
                                                ? loadingProgress!
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : 0;
                                            return Container(
                                              color: getBackgroundColor(
                                                backgroundColor,
                                              ),
                                              height: context.height(0.8),
                                              child:
                                                  CircularProgressIndicatorAnimateRotate(
                                                    progress: progress,
                                                  ),
                                            );
                                          }
                                          if (state.extendedImageLoadState ==
                                              LoadState.completed) {
                                            if (_failedToLoadImage.value ==
                                                true) {
                                              Future.delayed(
                                                const Duration(
                                                  milliseconds: 10,
                                                ),
                                              ).then(
                                                (value) =>
                                                    _failedToLoadImage.value =
                                                        false,
                                              );
                                            }
                                            return ExtendedImageGesture(
                                              state,
                                              canScaleImage: (_) => true,
                                              imageBuilder:
                                                  (
                                                    Widget image, {
                                                    ExtendedImageGestureState?
                                                    imageGestureState,
                                                  }) {
                                                    return image;
                                                  },
                                            );
                                          }
                                          if (state.extendedImageLoadState ==
                                              LoadState.failed) {
                                            if (_failedToLoadImage.value ==
                                                false) {
                                              Future.delayed(
                                                const Duration(
                                                  milliseconds: 10,
                                                ),
                                              ).then(
                                                (value) =>
                                                    _failedToLoadImage.value =
                                                        true,
                                              );
                                            }
                                            return Container(
                                              color: getBackgroundColor(
                                                backgroundColor,
                                              ),
                                              height: context.height(0.8),
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    l10n.image_loading_error,
                                                    style: TextStyle(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.7,
                                                          ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          8.0,
                                                        ),
                                                    child: GestureDetector(
                                                      onLongPress: () {
                                                        state.reLoadImage();
                                                        _failedToLoadImage
                                                                .value =
                                                            false;
                                                      },
                                                      onTap: () {
                                                        state.reLoadImage();
                                                        _failedToLoadImage
                                                                .value =
                                                            false;
                                                      },
                                                      child: Container(
                                                        decoration: BoxDecoration(
                                                          color: context
                                                              .primaryColor,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                30,
                                                              ),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                vertical: 8,
                                                                horizontal: 16,
                                                              ),
                                                          child: Text(
                                                            l10n.retry,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                          return const SizedBox.shrink();
                                        },
                                        initGestureConfigHandler: (state) {
                                          return GestureConfig(
                                            inertialSpeed: 200,
                                            inPageView: true,
                                            maxScale: 8,
                                            animationMaxScale: 8,
                                            cacheGesture: true,
                                            hitTestBehavior:
                                                HitTestBehavior.translucent,
                                          );
                                        },
                                        onDoubleTap: (state) {
                                          final Offset? pointerDownPosition =
                                              state.pointerDownPosition;
                                          final double? begin =
                                              state.gestureDetails!.totalScale;
                                          double end;

                                          //remove old
                                          _doubleClickAnimation?.removeListener(
                                            _doubleClickAnimationListener,
                                          );

                                          //stop pre
                                          _doubleClickAnimationController
                                              .stop();

                                          //reset to use
                                          _doubleClickAnimationController
                                              .reset();

                                          if (begin == doubleTapScales[0]) {
                                            end = doubleTapScales[1];
                                          } else {
                                            end = doubleTapScales[0];
                                          }

                                          _doubleClickAnimationListener = () {
                                            state.handleDoubleTap(
                                              scale:
                                                  _doubleClickAnimation!.value,
                                              doubleTapPosition:
                                                  pointerDownPosition,
                                            );
                                          };

                                          _doubleClickAnimation =
                                              Tween(
                                                begin: begin,
                                                end: end,
                                              ).animate(
                                                CurvedAnimation(
                                                  curve: Curves.ease,
                                                  parent:
                                                      _doubleClickAnimationController,
                                                ),
                                              );

                                          _doubleClickAnimation!.addListener(
                                            _doubleClickAnimationListener,
                                          );

                                          _doubleClickAnimationController
                                              .forward();
                                        },
                                        onLongPressData: (datas) {
                                          ImageActionsDialog.show(
                                            context: context,
                                            data: datas,
                                            manga: widget.chapter.manga.value!,
                                            chapterName: widget.chapter.name!,
                                          );
                                        },
                                      );
                                    },
                                    itemCount: pages.length,
                                    onPageChanged: _onPageChanged,
                                  ),
                          ),
                    Consumer(
                      builder: (context, ref, child) {
                        final usePageTapZones = ref.watch(
                          usePageTapZonesStateProvider,
                        );
                        final navigationLayout = ref.watch(
                          readerNavigationLayoutStateProvider,
                        );
                        final transformedContinuous =
                            _isContinuousMode() &&
                            (_currentContinuousScale() - _continuousBaseScale)
                                    .abs() >
                                0.01;
                        return IgnorePointer(
                          ignoring: transformedContinuous || useCanvasEngine,
                          child: ReaderGestureHandler(
                            usePageTapZones: usePageTapZones,
                            navigationLayout: navigationLayout,
                            isRTL: _isReverseHorizontal,
                            hasImageError: failedToLoadImage,
                            isContinuousMode: _isContinuousMode(),
                            onToggleUI: _isViewFunction,
                            onPreviousPage: () =>
                                _goPreviousInReader(readerMode!),
                            onNextPage: () => _goNextInReader(readerMode!),
                            onDoubleTapDown: (position) =>
                                _toggleScale(position),
                            onDoubleTap: () {},
                            onSecondaryTapDown: (position) =>
                                _toggleScale(position),
                            onSecondaryTap: () {},
                          ),
                        );
                      },
                    ),
                    ReaderAppBar(
                      chapter: chapter,
                      mangaName: _readerController.getMangaName(),
                      chapterTitle: _readerController.getChapterTitle(),
                      isVisible: _isView,
                      isBookmarked: _isBookmarked,
                      backgroundColor: _backgroundColor,
                      onBackPressed: () => Navigator.pop(context),
                      onBookmarkPressed: () {
                        _readerController.setChapterBookmarked();
                        setState(() {
                          _isBookmarked = !_isBookmarked;
                        });
                      },
                      onWebViewPressed:
                          (chapter.manga.value!.isLocalArchive ?? false) ==
                              false
                          ? () {
                              final data = buildWebViewData(chapter);
                              if (data != null) {
                                context.push("/mangawebview", extra: data);
                              }
                            }
                          : null,
                    ),
                    ReaderBottomBar(
                      chapter: chapter,
                      isVisible: _isView,
                      hasPreviousChapter:
                          _readerController.getChapterIndex().$1 + 1 !=
                          _readerController.getChaptersLength(
                            _readerController.getChapterIndex().$2,
                          ),
                      hasNextChapter:
                          _readerController.getChapterIndex().$1 != 0,
                      onPreviousChapter: () {
                        _isNavigatingToChapter = true;
                        pushReplacementMangaReaderView(
                          context: context,
                          chapter: _readerController.getPrevChapter(),
                        );
                      },
                      onNextChapter: () {
                        _isNavigatingToChapter = true;
                        pushReplacementMangaReaderView(
                          context: context,
                          chapter: _readerController.getNextChapter(),
                        );
                      },
                      onSliderChanged: (value, ref) {
                        if (_usesCanvasEngine(ref.read(_currentReaderMode)) &&
                            !_isCanvasSliderInteractionActive) {
                          _beginCanvasSliderInteraction();
                        }
                        ref
                            .read(currentIndexProvider(chapter).notifier)
                            .setCurrentIndex(value);
                      },
                      onSliderChangeStart: (value) {
                        _beginCanvasSliderInteraction();
                      },
                      onSliderChangeEnd: (value) {
                        try {
                          if (_usesCanvasEngine(ref.read(_currentReaderMode))) {
                            final targetChapterId =
                                _activeCanvasSliderChapterId ?? chapter.id;
                            final jumpIndex = _findCanvasScenePageIndex(
                              chapterId: targetChapterId!,
                              chapterPageIndex: value,
                            );
                            if (jumpIndex == null) {
                              _endCanvasSliderInteraction();
                              return;
                            }
                            _jumpToCanvasPageIndex(
                              jumpIndex,
                              animate: false,
                            );
                            _endCanvasSliderInteraction();
                            _onCanvasCameraChanged();
                            return;
                          }
                          final page = pages.firstWhere(
                            (element) =>
                                element.chapter == chapter &&
                                element.index == value,
                          );
                          int jumpIndex = page.pageIndex!;
                          // In double page mode, convert array index to page view index
                          if (_isDoublePageActive) {
                            jumpIndex = _actualToPageViewIndex(jumpIndex);
                          }
                          navigationService.jumpToPage(
                            index: jumpIndex,
                            readerMode: ref.read(_currentReaderMode)!,
                          );
                        } catch (_) {}
                        _endCanvasSliderInteraction();
                      },
                      onReaderModeChanged: (mode, ref) {
                        _applyReaderModeSelection(mode, ref);
                      },
                      onPageModeToggle: () async {
                        final readerMode = ref.read(_currentReaderMode);
                        if (readerMode != null &&
                            !isReaderModeContinuous(readerMode)) {
                          // Get the actual page index being viewed
                          final actualIdx = _pageViewToActualIndex(
                            _currentIndex!,
                          );
                          final pageIdx = pages[actualIdx].index ?? 0;
                          // Compute target index for the new mode
                          final int targetIndex;
                          if (_pageMode == PageMode.onePage) {
                            // Switching to double page: convert actual index to page view index
                            targetIndex = pageIdx ~/ 2;
                          } else {
                            // Switching to single page: use the actual page index
                            targetIndex = pageIdx;
                          }
                          navigationService.jumpToPage(
                            index: targetIndex,
                            readerMode: ref.read(_currentReaderMode)!,
                          );
                          PageMode newPageMode = _pageMode == PageMode.onePage
                              ? PageMode.doublePage
                              : PageMode.onePage;
                          _readerController.setPageMode(newPageMode);
                          if (mounted) {
                            setState(() {
                              _pageMode = newPageMode;
                            });
                          }
                        }
                      },
                      onSettingsPressed: () => ReaderSettingsModal.show(
                        context: context,
                        vsync: this,
                        currentReaderModeProvider: _currentReaderMode,
                        autoScroll: _autoScroll,
                        autoScrollPage: _autoScrollPage,
                        pageOffset: _pageOffset,
                        onAutoPageScroll: _autoPagescroll,
                        onReaderModeChanged: (mode, widgetRef) {
                          _applyReaderModeSelection(mode, widgetRef);
                        },
                        onAutoScrollSave: (enabled, offset) {
                          _readerController.setAutoScroll(enabled, offset);
                        },
                        onFullScreenToggle: () {
                          final fullScreen = ref.read(
                            fullScreenReaderStateProvider,
                          );
                          _setFullScreen(value: !fullScreen);
                        },
                      ),
                      currentReaderModeProvider: _currentReaderMode,
                      currentIndexProvider: currentIndexProvider,
                      currentPageMode: _pageMode,
                      isReverseHorizontal: _isReverseHorizontal,
                      totalPages: _readerController.getPageLength(
                        _chapterUrlModel.pageUrls,
                      ),
                      currentIndexLabel: _currentIndexLabel,
                      backgroundColor: _backgroundColor,
                    ),
                    PageIndicator(
                      chapter: chapter,
                      isUiVisible: _isView,
                      totalPages: _readerController.getPageLength(
                        _chapterUrlModel.pageUrls,
                      ),
                      formatCurrentIndex: _currentIndexLabel,
                    ),
                    ReaderAutoScrollButton(
                      isContinuousMode: _isContinuousMode(),
                      isUiVisible: _isView,
                      autoScrollPage: _autoScrollPage,
                      autoScroll: _autoScroll,
                      onToggle: () {
                        _autoPagescroll();
                        _autoScroll.value = !_autoScroll.value;
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Duration? _doubleTapAnimationDuration() {
    int doubleTapAnimationValue = isar.settings
        .getSync(227)!
        .doubleTapAnimationSpeed!;
    if (doubleTapAnimationValue == 0) {
      return const Duration(milliseconds: 10);
    } else if (doubleTapAnimationValue == 1) {
      return const Duration(milliseconds: 180);
    }
    return const Duration(milliseconds: 150);
  }

  void _readProgressListener() async {
    if (_isAdjustingScroll) return;
    final itemPositions = _itemPositionsListener.itemPositions.value;
    if (itemPositions.isEmpty) return;
    _currentIndex = itemPositions.first.index;
    if (!_isScrolling.value) _isScrolling.value = true;
    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted) _isScrolling.value = false;
    });
    final currentReaderMode = ref.read(_currentReaderMode);
    int pagesLength =
        (_pageMode == PageMode.doublePage &&
            currentReaderMode != null &&
            !isReaderModeContinuous(currentReaderMode))
        ? (pages.length / 2).ceil()
        : pages.length;
    if (_currentIndex! >= 0 && _currentIndex! < pagesLength) {
      if (_readerController.chapter.id != pages[_currentIndex!].chapter!.id) {
        if (mounted) {
          setState(() {
            _readerController = ref.read(
              readerControllerProvider(
                chapter: pages[_currentIndex!].chapter!,
              ).notifier,
            );

            chapter = pages[_currentIndex!].chapter!;
            final chapterUrlModel = pages[_currentIndex!].chapterUrlModel;

            if (chapterUrlModel != null) {
              _chapterUrlModel = chapterUrlModel;
            }

            _isBookmarked = _readerController.getChapterBookmarked();
          });
        }
      }

      // ── Next-chapter preloading: trigger when near the end ──
      final distToEnd = pagesLength - 1 - itemPositions.last.index;
      if (distToEnd <= pagePreloadAmount && !_isLastPageTransition) {
        _triggerNextChapterPreload();
      }

      // ── Previous-chapter preloading: trigger when near the start ──
      if (itemPositions.first.index <= pagePreloadAmount) {
        _triggerPrevChapterPreload();
      }

      final idx = pages[_currentIndex!].index;
      if (idx != null) {
        _readerController.setPageIndex(
          _isDoublePageActive ? idx : _geCurrentIndex(idx),
          false,
        );
        ref.read(currentIndexProvider(chapter).notifier).setCurrentIndex(idx);
      }
    }
  }

  void _addLastPageTransition(Chapter chap) {
    if (_isLastPageTransition) return;
    try {
      if (!mounted || pageCount == 0) return;
      if (pages.last.isLastChapter ?? false) return;

      final added = addLastChapterTransition(chap);
      if (added && mounted) {
        setState(() {
          _isLastPageTransition = true;
        });
      }
    } catch (_) {}
  }

  void _preloadNextChapter(GetChapterPagesModel chapterData, Chapter chap) {
    try {
      if (chapterData.uChapDataPreload.isEmpty || !mounted) return;

      final firstChapter = chapterData.uChapDataPreload.first.chapter;
      if (firstChapter == null) return;

      // Use mixin's method for memory-bounded preloading with auto-eviction
      preloadNextChapter(chapterData, chap).then((success) {
        if (success && mounted) {
          if (_usesCanvasEngine(ref.read(_currentReaderMode))) {
            _scheduleCanvasSceneRebuild();
          } else {
            setState(() {});
          }
        }
      });
    } catch (_) {}
  }

  // bidirectional proactive chapter preloading ──

  /// Proactively starts loading both adjacent chapters at reader init.
  void _proactivePreload() {
    _triggerNextChapterPreload();
    _triggerPrevChapterPreload();
  }

  /// Fires off next-chapter page fetching if not already in progress.
  void _triggerNextChapterPreload() async {
    if (_isNextChapterPreloading || _isLastPageTransition) return;
    _isNextChapterPreloading = true;
    try {
      if (!mounted) return;
      final nextChapter = _readerController.getNextChapter();
      if (isChapterLoaded(nextChapter)) {
        _isNextChapterPreloading = false;
        return;
      }
      final value = await ref.read(
        getChapterPagesProvider(chapter: nextChapter).future,
      );
      if (mounted) {
        _preloadNextChapter(value, chapter);
      }
      _isNextChapterPreloading = false;
    } on RangeError {
      _isNextChapterPreloading = false;
      _addLastPageTransition(chapter);
    } catch (_) {
      _isNextChapterPreloading = false;
    }
  }

  /// Fires off previous-chapter page fetching and prepends pages.
  void _triggerPrevChapterPreload() async {
    if (_isPrevChapterPreloading) return;
    _isPrevChapterPreloading = true;
    try {
      if (!mounted) return;
      final prevChapter = _readerController.getPrevChapter();
      if (isChapterLoaded(prevChapter)) {
        _isPrevChapterPreloading = false;
        return;
      }
      final value = await ref.read(
        getChapterPagesProvider(chapter: prevChapter).future,
      );
      if (mounted) {
        _handlePrevChapterPrepended(value, chapter);
      }
    } on RangeError {
      // No previous chapter — nothing to prepend
    } catch (_) {}
    _isPrevChapterPreloading = false;
  }

  /// Prepends previous-chapter pages and adjusts scroll position to avoid jump.
  void _handlePrevChapterPrepended(
    GetChapterPagesModel chapterData,
    Chapter chap,
  ) {
    try {
      if (chapterData.uChapDataPreload.isEmpty || !mounted) return;

      if (_usesCanvasEngine(ref.read(_currentReaderMode))) {
        final anchor = _captureCanvasAnchor();
        preloadPreviousChapter(chapterData, chap).then((prependCount) {
          if (prependCount > 0 && mounted) {
            _pendingCanvasAnchor = anchor;
            _currentIndex = (_currentIndex ?? 0) + prependCount;
            _canvasVisiblePageIndex = null;
            _canvasCameraInitialized = true;
            _scheduleCanvasSceneRebuild(preserveAnchor: false);
          }
        });
        return;
      }

      // Record the CURRENT visible top index BEFORE prepending
      final currentVisibleItems = _itemPositionsListener.itemPositions.value;
      final oldTopIndex = currentVisibleItems.isNotEmpty
          ? currentVisibleItems.first.index
          : _currentIndex ?? 0;

      preloadPreviousChapter(chapterData, chap).then((prependCount) {
        if (prependCount > 0 && mounted) {
          _isAdjustingScroll = true;

          // New index = old visible index + how many items we just prepended
          final newIndex = oldTopIndex + prependCount;

          // In double page mode, _currentIndex stores the page view index,
          // so convert the prepended page count to page view units.
          if (_isDoublePageActive) {
            // Recompute the page view index from the new actual index.
            final oldActual = _pageViewToActualIndex(oldTopIndex);
            final newActual = oldActual + prependCount;
            _currentIndex = _actualToPageViewIndex(newActual);
          } else {
            _currentIndex = newIndex;
          }
          setState(() {});
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              if (_isContinuousMode()) {
                _itemScrollController.jumpTo(index: newIndex);
              } else if (_extendedController.hasClients) {
                _extendedController.jumpToPage(_currentIndex!);
              }
              _isAdjustingScroll = false;
            }
          });
        }
      });
    } catch (_) {}
  }

  void _initCurrentIndex() async {
    if (ref.read(cropBordersStateProvider)) _processCropBorders();
    final readerMode = normalizeReaderMode(_readerController.getReaderMode());

    // Initialize the preload manager with bounded memory (from ReaderMemoryManagement mixin)
    initializePreloadManager(
      _chapterUrlModel,
      onPagesUpdated: () {
        if (mounted) {
          if (_usesCanvasEngine(ref.read(_currentReaderMode))) {
            _scheduleCanvasSceneRebuild();
          } else {
            setState(() {});
          }
          if (ref.read(cropBordersStateProvider)) _processCropBorders();
        }
      },
    );

    // proactively start loading adjacent chapters in background
    _proactivePreload();

    _readerController.setMangaHistoryUpdate();
    // Use post-frame callback instead of Future.delayed(1ms) timing hack
    await Future(() {});
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    if (fullScreenReader) {
      if (isDesktop) {
        setFullScreen(value: true);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    }
    ref.read(_currentReaderMode.notifier).state = readerMode;
    _syncReaderModeSettings(readerMode, ref);
    if (mounted) {
      setState(() {
        _pageMode = _readerController.getPageMode();
      });
    }
    _setReaderMode(readerMode, ref);

    if (!isReaderModeContinuous(readerMode)) {
      _autoScroll.value = false;
    }
    _autoPagescroll();
    if (_readerController.getPageLength(_chapterUrlModel.pageUrls) == 1 &&
        isReaderModePaged(readerMode)) {
      _onPageChanged(0);
    }
  }

  Future<void> _onPageChanged(int index) async {
    // In non-continuous double page mode, convert page view index to actual
    // pages array index for correct lookups.
    final int actualIndex = _pageViewToActualIndex(index);
    final int prevActualIndex = _pageViewToActualIndex(_currentIndex!);

    final cropBorders = ref.watch(cropBordersStateProvider);
    if (cropBorders) {
      _processCropBordersByIndex(index);
    }
    if (_firstLaunch && !_usesCanvasEngine(ref.read(_currentReaderMode))) {
      Future.delayed(const Duration(milliseconds: 100)).then((_) {
        _firstLaunch = false;
      });
      return;
    }
    _firstLaunch = false;
    final idx = pages[prevActualIndex].index;
    if (idx != null) {
      _readerController.setPageIndex(
        _isDoublePageActive ? idx : _geCurrentIndex(idx),
        false,
      );
    }
    if (_readerController.chapter.id != pages[actualIndex].chapter!.id) {
      if (mounted) {
        setState(() {
          _readerController = ref.read(
            readerControllerProvider(
              chapter: pages[actualIndex].chapter!,
            ).notifier,
          );
          chapter = pages[actualIndex].chapter!;
          final chapterUrlModel = pages[actualIndex].chapterUrlModel;
          if (chapterUrlModel != null) {
            _chapterUrlModel = chapterUrlModel;
          }
          _isBookmarked = _readerController.getChapterBookmarked();
        });
      }
    }
    // Reset zoom of the previous page so user can swipe back freely (#443).
    clearGestureDetailsCache();
    _currentIndex = index;
    if (pages[actualIndex].index != null) {
      ref
          .read(currentIndexProvider(chapter).notifier)
          .setCurrentIndex(pages[actualIndex].index!);
    }

    // ── Next-chapter preloading: trigger when near the end ──
    final distToEnd = pages.length - 1 - actualIndex;
    if (distToEnd <= pagePreloadAmount && !_isLastPageTransition) {
      _triggerNextChapterPreload();
    }

    // ── Previous-chapter preloading: trigger when near the start ──
    if (actualIndex <= pagePreloadAmount) {
      _triggerPrevChapterPreload();
    }
  }

  late final _pageOffset = ValueNotifier(
    _readerController.autoScrollValues().$2,
  );

  void _autoPagescroll() async {
    if (_isContinuousMode()) {
      for (int i = 0; i < 1; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (!_autoScroll.value) {
          return;
        }
        if (_usesCanvasEngine(ref.read(_currentReaderMode))) {
          _canvasCameraController.panBy(Offset(0, -_pageOffset.value));
        } else {
          _pageOffsetController.animateScroll(
            offset: _pageOffset.value,
            duration: const Duration(milliseconds: 100),
          );
        }
      }
      _autoPagescroll();
    }
  }

  void _toggleScale(Offset globalPosition) {
    if (!mounted || _scaleAnimationController.isAnimating) {
      return;
    }

    final currentScale = _currentContinuousScale();
    final shouldZoomIn = (currentScale - _continuousBaseScale).abs() < 0.05;
    _animateContinuousScale(
      shouldZoomIn ? _continuousDoubleTapScale : _continuousBaseScale,
      localFocalPoint: _readerLocalPointFromGlobal(globalPosition),
    );
  }

  void _syncReaderModeSettings(ReaderMode mode, WidgetRef ref) {
    ref
        .read(showPageGapsStateProvider.notifier)
        .set(isReaderModeLongStripWithGaps(mode));
  }

  void _applyReaderModeSelection(ReaderMode mode, WidgetRef ref) {
    final normalizedMode = normalizeReaderMode(mode);
    _syncReaderModeSettings(normalizedMode, ref);
    ref.read(_currentReaderMode.notifier).state = normalizedMode;
    _setReaderMode(normalizedMode, ref);
  }

  void _setReaderMode(ReaderMode value, WidgetRef ref) async {
    final normalizedMode = normalizeReaderMode(value);
    if (!isReaderModeContinuous(normalizedMode)) {
      _autoScroll.value = false;
    } else {
      if (_autoScrollPage.value) {
        _autoPagescroll();
        _autoScroll.value = true;
      }
    }

    _failedToLoadImage.value = false;
    _continuousScale = _continuousBaseScale;
    _continuousPanOffset = Offset.zero;
    _continuousPointerCount = 0;
    _desktopZoomModifierPressed = false;
    _continuousActivePointers.clear();
    _canvasCameraController.stopMotion();
    _canvasScene = ReaderScene.empty;
    _canvasViewportSize = Size.zero;
    _canvasVisiblePageIndex = null;
    _canvasCameraInitialized = false;
    _pendingCanvasAnchor = null;
    _isCanvasSliderInteractionActive = false;
    _activeCanvasSliderChapterId = null;
    _readerController.setReaderMode(normalizedMode);

    int index = _pageViewToActualIndex(_currentIndex!);
    ref.read(_currentReaderMode.notifier).state = normalizedMode;
    if (normalizedMode == ReaderMode.vertical) {
      if (mounted) {
        setState(() {
          _scrollDirection = Axis.vertical;
          _isReverseHorizontal = false;
        });
        // Wait for the next frame so the PageView rebuilds with new direction
        await WidgetsBinding.instance.endOfFrame;

        _extendedController.jumpToPage(index);
      }
    } else if (isReaderModeHorizontalPaged(normalizedMode)) {
      if (mounted) {
        setState(() {
          if (normalizedMode == ReaderMode.rtl) {
            _isReverseHorizontal = true;
          } else {
            _isReverseHorizontal = false;
          }

          _scrollDirection = Axis.horizontal;
        });
        // Wait for the next frame so the PageView rebuilds with new direction
        await WidgetsBinding.instance.endOfFrame;

        _extendedController.jumpToPage(index);
      }
    } else {
      if (mounted) {
        setState(() {
          _isReverseHorizontal = false;
        });
        // Wait for the next frame so the scroll view rebuilds
        await WidgetsBinding.instance.endOfFrame;
        _itemScrollController.scrollTo(
          index: index,
          duration: const Duration(milliseconds: 1),
          curve: Curves.ease,
        );
      }
    }
  }

  void _processCropBordersByIndex(int index) async {
    if (!_cropBorderCheckList.contains(index)) {
      _cropBorderCheckList.add(index);
      if (!mounted) return;
      final value = await ref.read(
        cropBordersProvider(data: pages[index], cropBorder: true).future,
      );
      if (mounted) {
        updatePageCropImage(index, value);
      }
    }
  }

  bool _isCropBordersProcessing = false;
  void _processCropBorders() async {
    if (_isCropBordersProcessing ||
        _cropBorderCheckList.length == pages.length) {
      return;
    }
    _isCropBordersProcessing = true;

    try {
      for (var i = 0; i < pages.length; i++) {
        if (!_cropBorderCheckList.contains(i)) {
          _cropBorderCheckList.add(i);
          if (!mounted) return;
          final value = await ref.read(
            cropBordersProvider(data: pages[i], cropBorder: true).future,
          );
          if (mounted) {
            updatePageCropImage(i, value);
          }
        }
      }
    } finally {
      _isCropBordersProcessing = false;
    }
  }

  void _goBack(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    Navigator.pop(context);
  }

  void _isViewFunction() {
    final fullScreenReader = ref.watch(fullScreenReaderStateProvider);
    if (context.mounted) {
      setState(() {
        _isView = !_isView;
      });
    }
    if (fullScreenReader) {
      if (_isView) {
        SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.manual,
          overlays: SystemUiOverlay.values,
        );
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      }
    }
  }

  String _currentIndexLabel(int index) {
    if (_pageMode != PageMode.doublePage) {
      return "${index + 1}";
    }
    int pageLength = _readerController.getPageLength(_chapterUrlModel.pageUrls);
    int page1 = index + 1;
    int page2 = index + 2;
    return page2 > pageLength ? "$pageLength" : "$page1-$page2";
  }

  int _geCurrentIndex(int index) {
    return index;
  }

  /// Whether double page mode is active (continuous or paged).
  /// Long strip modes do NOT use double page layout.
  bool get _isDoublePageActive =>
      _pageMode == PageMode.doublePage &&
      !isReaderModeContinuous(ref.read(_currentReaderMode)!);

  /// Converts a page view index (from ExtendedPageController) to the actual
  /// index in the [pages] array for double page mode.
  ///
  /// In double page mode:
  ///   PV 0 → pages[0] (first page shown solo)
  ///   PV n (n>0) → pages[2n-1] (first page of the pair)
  int _pageViewToActualIndex(int pageViewIndex) {
    if (!_isDoublePageActive) return pageViewIndex;
    return (pageViewIndex * 2).clamp(0, pages.length - 1);
  }

  /// Converts an actual [pages] array index to a page view index
  /// for double page mode.
  int _actualToPageViewIndex(int actualIndex) {
    if (!_isDoublePageActive) return actualIndex;
    return actualIndex ~/ 2;
  }

  /// Total page count as seen by the page view controller.
  /// In double page mode, each PV page shows 2 actual pages.
  int get _pageViewPageCount =>
      _isDoublePageActive ? (pages.length / 2).ceil() : pages.length;

  bool _isContinuousMode() {
    final readerMode = ref.read(_currentReaderMode);
    return readerMode != null && isReaderModeContinuous(readerMode);
  }
}
