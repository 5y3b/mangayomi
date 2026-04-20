import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';

import 'package:mangayomi/modules/manga/reader/reader_canvas/reader_camera_clamp.dart';

@immutable
class ReaderCameraState {
  const ReaderCameraState({
    required this.scale,
    required this.translation,
  });

  final double scale;
  final Offset translation;

  ReaderCameraState copyWith({
    double? scale,
    Offset? translation,
  }) {
    return ReaderCameraState(
      scale: scale ?? this.scale,
      translation: translation ?? this.translation,
    );
  }
}

class ReaderCameraController extends ChangeNotifier {
  ReaderCameraController({
    ReaderCameraState? initialState,
    this.minScale = 0.35,
    this.maxScale = 6.0,
  }) : _state =
           initialState ??
           const ReaderCameraState(scale: 1.0, translation: Offset.zero);

  final double minScale;
  final double maxScale;

  ReaderCameraState _state;
  ReaderCameraState get state => _state;

  Rect? _sceneBounds;
  Size? _viewportSize;

  Ticker? _ticker;
  Duration? _lastTick;
  Simulation? _flingX;
  Simulation? _flingY;
  ReaderCameraState? _animationFrom;
  ReaderCameraState? _animationTo;
  Duration _animationDuration = Duration.zero;
  Curve _animationCurve = Curves.linear;
  Duration _animationElapsed = Duration.zero;

  void updateConstraints({
    required Rect sceneBounds,
    required Size viewportSize,
  }) {
    final previousBounds = _sceneBounds;
    final previousViewport = _viewportSize;
    final previousState = _state;
    _sceneBounds = sceneBounds;
    _viewportSize = viewportSize;
    _applyState(_state, clampToScene: true, notify: false);
    if (previousBounds != sceneBounds ||
        previousViewport != viewportSize ||
        previousState != _state) {
      notifyListeners();
    }
  }

  void setScale(double scale) {
    _applyState(_state.copyWith(scale: _clampScale(scale)));
  }

  void setTranslation(Offset translation) {
    _applyState(_state.copyWith(translation: translation));
  }

  void zoomAround(Offset viewportPoint, double nextScale) {
    final clampedScale = _clampScale(nextScale);
    final worldFocalPoint = viewportToWorld(viewportPoint);
    final nextTranslation = viewportPoint - worldFocalPoint * clampedScale;
    _applyState(
      ReaderCameraState(
        scale: clampedScale,
        translation: nextTranslation,
      ),
    );
  }

  void panBy(Offset delta) {
    _applyState(
      _state.copyWith(translation: _state.translation + delta),
    );
  }

  void animateTo({
    double? scale,
    Offset? translation,
    Duration duration = const Duration(milliseconds: 220),
    Curve curve = Curves.easeOutCubic,
  }) {
    stopMotion();
    _animationFrom = _state;
    _animationTo = ReaderCameraState(
      scale: _clampScale(scale ?? _state.scale),
      translation: translation ?? _state.translation,
    );
    _animationDuration = duration;
    _animationCurve = curve;
    _animationElapsed = Duration.zero;
    _ensureTicker();
  }

  void fling(Offset velocity) {
    stopMotion();
    _flingX = FrictionSimulation(0.00003, _state.translation.dx, velocity.dx);
    _flingY = FrictionSimulation(0.00003, _state.translation.dy, velocity.dy);
    _ensureTicker();
  }

  Rect visibleWorldRect(Size viewportSize) {
    final width = viewportSize.width / math.max(_state.scale, 0.01);
    final height = viewportSize.height / math.max(_state.scale, 0.01);
    final left = -_state.translation.dx / math.max(_state.scale, 0.01);
    final top = -_state.translation.dy / math.max(_state.scale, 0.01);
    return Rect.fromLTWH(left, top, width, height);
  }

  Offset worldToViewport(Offset worldPoint) {
    return Offset(
      worldPoint.dx * _state.scale + _state.translation.dx,
      worldPoint.dy * _state.scale + _state.translation.dy,
    );
  }

  Offset viewportToWorld(Offset viewportPoint) {
    return Offset(
      (viewportPoint.dx - _state.translation.dx) / math.max(_state.scale, 0.01),
      (viewportPoint.dy - _state.translation.dy) / math.max(_state.scale, 0.01),
    );
  }

  void stopMotion() {
    _ticker?.stop();
    _lastTick = null;
    _flingX = null;
    _flingY = null;
    _animationFrom = null;
    _animationTo = null;
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  double _clampScale(double scale) {
    return scale.clamp(minScale, maxScale).toDouble();
  }

  void _applyState(
    ReaderCameraState nextState, {
    bool clampToScene = true,
    bool notify = true,
  }) {
    var appliedState = nextState.copyWith(scale: _clampScale(nextState.scale));
    final sceneBounds = _sceneBounds;
    final viewportSize = _viewportSize;
    if (clampToScene && sceneBounds != null && viewportSize != null) {
      final clampResult = ReaderCameraClamp.clamp(
        state: appliedState,
        sceneBounds: sceneBounds,
        viewportSize: viewportSize,
      );
      appliedState = appliedState.copyWith(
        translation: clampResult.translation,
      );
    }

    if (_state.scale == appliedState.scale &&
        _state.translation == appliedState.translation) {
      return;
    }

    _state = appliedState;
    if (notify) {
      notifyListeners();
    }
  }

  void _ensureTicker() {
    _ticker ??= Ticker(_onTick);
    _lastTick = null;
    if (!(_ticker?.isActive ?? false)) {
      _ticker?.start();
    }
  }

  void _onTick(Duration elapsed) {
    final lastTick = _lastTick;
    _lastTick = elapsed;
    if (lastTick == null) {
      return;
    }

    final dt = elapsed - lastTick;
    if (_animationFrom != null && _animationTo != null) {
      _animationElapsed += dt;
      final totalMicros = math.max(_animationDuration.inMicroseconds, 1);
      final rawT = _animationElapsed.inMicroseconds / totalMicros;
      final t = rawT.clamp(0.0, 1.0);
      final curvedT = _animationCurve.transform(t);
      final begin = _animationFrom!;
      final end = _animationTo!;
      _applyState(
        ReaderCameraState(
          scale: lerpDouble(begin.scale, end.scale, curvedT) ?? end.scale,
          translation:
              Offset.lerp(begin.translation, end.translation, curvedT) ??
              end.translation,
        ),
      );
      if (t >= 1.0) {
        _animationFrom = null;
        _animationTo = null;
        _maybeStopTicker();
      }
      return;
    }

    if (_flingX == null || _flingY == null) {
      _maybeStopTicker();
      return;
    }

    final timeSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final nextState = _state.copyWith(
      translation: Offset(
        _flingX!.x(timeSeconds),
        _flingY!.x(timeSeconds),
      ),
    );
    _applyState(nextState);

    final sceneBounds = _sceneBounds;
    final viewportSize = _viewportSize;
    final doneX = _flingX!.isDone(timeSeconds);
    final doneY = _flingY!.isDone(timeSeconds);
    final hitBoundary = sceneBounds != null &&
        viewportSize != null &&
        ReaderCameraClamp.clamp(
              state: _state,
              sceneBounds: sceneBounds,
              viewportSize: viewportSize,
            )
                .translation !=
            nextState.translation;

    if ((doneX && doneY) || hitBoundary) {
      _flingX = null;
      _flingY = null;
      _maybeStopTicker();
    }
  }

  void _maybeStopTicker() {
    if (_animationFrom == null &&
        _animationTo == null &&
        _flingX == null &&
        _flingY == null) {
      _ticker?.stop();
      _lastTick = null;
    }
  }
}
