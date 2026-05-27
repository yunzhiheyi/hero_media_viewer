import 'package:flutter/material.dart';
import 'custom_dismissible.dart';
import 'interactive_viewer_boundary.dart';

typedef IndexedFocusedWidgetBuilder =
    Widget Function(BuildContext context, int index, bool isFocus);

class InteractiveGalleryViewer<T> extends StatefulWidget {
  const InteractiveGalleryViewer({
    super.key,
    required this.sources,
    required this.initIndex,
    required this.itemBuilder,
    this.appBar,
    this.maxScale = 3.5,
    this.minScale = 1.0,
    this.onPageChanged,
    this.onCloseRequested,
    this.isSingle = false,
    this.enableIndicator = false,
    this.showBackground = true,
    this.showAppBar = true,
    this.tapToDismiss = true,
    this.dismissEnabled = true,
    this.externalVerticalDragStart,
    this.externalVerticalDragUpdate,
    this.externalVerticalDragEnd,
    this.onDismissDragStart,
    this.onDismissDragCancel,
  });

  final bool isSingle;
  final bool enableIndicator;
  final List<T> sources;
  final int initIndex;
  final Widget? appBar;
  final IndexedFocusedWidgetBuilder itemBuilder;
  final double maxScale;
  final double minScale;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onCloseRequested;
  final VoidCallback? onDismissDragStart;
  final VoidCallback? onDismissDragCancel;
  final bool showBackground;
  final bool showAppBar;
  final bool tapToDismiss;
  final bool dismissEnabled;
  final GestureDragStartCallback? externalVerticalDragStart;
  final GestureDragUpdateCallback? externalVerticalDragUpdate;
  final GestureDragEndCallback? externalVerticalDragEnd;

  @override
  State<InteractiveGalleryViewer> createState() =>
      _InteractiveGalleryViewerState();
}

class _InteractiveGalleryViewerState extends State<InteractiveGalleryViewer>
    with TickerProviderStateMixin {
  PageController? _pageController;
  TransformationController? _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  bool _enablePageView = true;
  bool _enableDismiss = true;
  late Offset _doubleTapLocalPosition;
  int? currentIndex;
  bool isDismissDrag = false;
  int currentTouchPointNum = 0;
  double _dragProgress = 0;
  double _currentScale = 1.0;

  // zoom 状态下"过拖（over-pan）转下滑关闭"的状态机
  Offset? _lastPointerPosition;
  double _lastTranslationY = 0;
  bool _externalDragActive = false;

  // 防止 mid-gesture rebuild 引起 InteractiveViewer 焦点漂移：
  // 手指还在屏幕上时，不要因 scale 变化触发 _setGestureMode 重建。
  bool get _gestureInProgress => currentTouchPointNum > 0;

  bool get _hasExternalVerticalDrag =>
      widget.externalVerticalDragStart != null &&
      widget.externalVerticalDragUpdate != null &&
      widget.externalVerticalDragEnd != null;

  @override
  void initState() {
    super.initState();
    if (!widget.isSingle) {
      _pageController = PageController(initialPage: widget.initIndex);
    }
    _transformationController = TransformationController();
    _animationController =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 300),
          )
          ..addListener(() {
            _transformationController!.value =
                _animation?.value ?? Matrix4.identity();
          })
          ..addStatusListener((AnimationStatus status) {
            if (status == AnimationStatus.completed && !_enableDismiss) {
              setState(() {
                _enableDismiss = true;
              });
            }
          });

    currentIndex = widget.initIndex;
  }

  @override
  void dispose() {
    if (!widget.isSingle) {
      _pageController!.dispose();
    }
    _transformationController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _isAtRestScale(double scale) {
    return scale <= 1.01;
  }

  void _setGestureMode({
    required bool enablePageView,
    required bool enableDismiss,
  }) {
    if (_enablePageView == enablePageView && _enableDismiss == enableDismiss) {
      return;
    }

    setState(() {
      _enablePageView = enablePageView;
      _enableDismiss = enableDismiss;
    });
  }

  void _onScaleChanged(double scale) {
    _currentScale = scale;
    // 手势进行中，先不调整 panEnabled/scaleEnabled 这类影响 InteractiveViewer 的状态，
    // 否则 InteractiveViewer 在 pinch 过程中重建会导致焦点跳动 / 图片漂移。
    if (_gestureInProgress) {
      return;
    }
    _evalScaleMode();
  }

  void _evalScaleMode() {
    if (_isAtRestScale(_currentScale)) {
      _setGestureMode(enablePageView: true, enableDismiss: true);
    } else {
      _setGestureMode(enablePageView: false, enableDismiss: false);
    }
  }

  // 单指移动处理：
  // - rest scale（_isAtRestScale）下，外层 GestureDetector 的 onVerticalDrag 会收到；
  //   这里只兜底处理 zoom 状态下的"过拖（over-pan）转下滑关闭"。
  // - zoom 状态下，InteractiveViewer 自己消化平移；当图片到达顶部边界后，多余的
  //   下滑距离会"丢失"（matrix 不再更新），我们把丢失量转交给外层 dismiss handler。
  void _handleSingleFingerMove(PointerMoveEvent event) {
    final last = _lastPointerPosition;
    if (last == null) {
      _lastPointerPosition = event.position;
      return;
    }
    final pointerDeltaY = event.position.dy - last.dy;
    _lastPointerPosition = event.position;

    if (_isAtRestScale(_currentScale)) {
      // rest scale 时，由 _buildItem 的 GestureDetector.onVerticalDrag 处理。
      _lastTranslationY = _transformationController!.value.getTranslation().y;
      return;
    }

    // zoom 状态：检测过拖
    final translationY = _transformationController!.value.getTranslation().y;
    final translationDeltaY = translationY - _lastTranslationY;
    _lastTranslationY = translationY;

    // 用户向下拖（pointerDeltaY > 0），但 matrix 没跟上（已被边界 clamp）
    final lostDY = pointerDeltaY - translationDeltaY;
    if (pointerDeltaY > 0 && lostDY > 0.5) {
      if (!_externalDragActive) {
        _externalDragActive = true;
        widget.externalVerticalDragStart?.call(
          DragStartDetails(
            globalPosition: event.position,
            localPosition: event.localPosition,
          ),
        );
      }
      widget.externalVerticalDragUpdate?.call(
        DragUpdateDetails(
          delta: Offset(0, lostDY),
          primaryDelta: lostDY,
          globalPosition: event.position,
          localPosition: event.localPosition,
        ),
      );
    } else if (_externalDragActive && pointerDeltaY < 0) {
      // 反向移动：取消已经开始的外部拖动（图片重新进入可平移区域）
      _cancelExternalDragIfAny();
    }
  }

  void _cancelExternalDragIfAny() {
    if (_externalDragActive) {
      widget.externalVerticalDragEnd?.call(
        DragEndDetails(velocity: Velocity.zero),
      );
      _externalDragActive = false;
    }
  }

  void _onLeftBoundaryHit() {
    _enablePageViewAtZoomBoundary(isLeftBoundary: true);
  }

  void _onRightBoundaryHit() {
    _enablePageViewAtZoomBoundary(isLeftBoundary: false);
  }

  void _enablePageViewAtZoomBoundary({required bool isLeftBoundary}) {
    if (_pageController != null &&
        _pageController!.hasClients &&
        !_enablePageView &&
        _pageController!.page != null &&
        !widget.isSingle) {
      final page = _pageController!.page!.round();
      final canMoveToPrevious = page > 0;
      final canMoveToNext = page < widget.sources.length - 1;

      if ((isLeftBoundary && canMoveToPrevious) ||
          (!isLeftBoundary && canMoveToNext)) {
        setState(() {
          _enablePageView = true;
        });
      }
    }
  }

  void _onNoBoundaryHit() {
    if (_enablePageView) {
      setState(() {
        _enablePageView = false;
      });
    }
  }

  void _onPageChanged(int page) {
    setState(() {
      currentIndex = page;
      _enablePageView = true;
      _enableDismiss = true;
    });
    widget.onPageChanged?.call(page);
    if (_transformationController!.value != Matrix4.identity()) {
      _transformationController!.value = Matrix4.identity();
      _currentScale = 1.0;
    }
  }

  void _onDragProgress(double progress) {
    setState(() {
      _dragProgress = progress;
    });
  }

  void _closeWithAnimation() {
    setState(() {
      _dragProgress = 1.0;
      isDismissDrag = true;
      _enablePageView = false;
    });

    if (mounted) {
      if (widget.onCloseRequested != null) {
        widget.onCloseRequested!.call();
      } else {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - _dragProgress).clamp(0.0, 1.0);
    final reserveSingleFingerDrag =
        _hasExternalVerticalDrag &&
        _isAtRestScale(_currentScale) &&
        currentTouchPointNum <= 1;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (widget.showBackground)
            Container(
              color: Colors.black.withValues(alpha: bgOpacity),
              width: double.infinity,
              height: double.infinity,
            ),
          InteractiveViewerBoundary(
            controller: _transformationController,
            boundaryWidth: MediaQuery.of(context).size.width,
            onScaleChanged: _onScaleChanged,
            onLeftBoundaryHit: _onLeftBoundaryHit,
            onRightBoundaryHit: _onRightBoundaryHit,
            onNoBoundaryHit: _onNoBoundaryHit,
            maxScale: widget.maxScale,
            minScale: widget.minScale,
            scaleEnabled: !reserveSingleFingerDrag,
            panEnabled:
                !_hasExternalVerticalDrag || !_isAtRestScale(_currentScale),
            child: Listener(
              onPointerDown: (event) {
                currentTouchPointNum++;
                if (currentTouchPointNum == 1) {
                  _lastPointerPosition = event.position;
                  _lastTranslationY =
                      _transformationController!.value.getTranslation().y;
                } else if (currentTouchPointNum > 1) {
                  // 第 2 指落下：取消任何进行中的外部拖动（pinch 优先）
                  _cancelExternalDragIfAny();
                  setState(() {
                    _enablePageView = false;
                  });
                }
              },
              onPointerMove: (event) {
                if (currentTouchPointNum == 1 && _hasExternalVerticalDrag) {
                  _handleSingleFingerMove(event);
                }
              },
              onPointerUp: (event) {
                currentTouchPointNum =
                    (currentTouchPointNum - 1).clamp(0, 10).toInt();
                if (_externalDragActive) {
                  widget.externalVerticalDragEnd?.call(
                    DragEndDetails(velocity: Velocity.zero),
                  );
                  _externalDragActive = false;
                }
                if (currentTouchPointNum == 0) {
                  _lastPointerPosition = null;
                  _evalScaleMode();
                } else if (currentTouchPointNum <= 1 &&
                    _isAtRestScale(_currentScale)) {
                  setState(() => _enablePageView = true);
                }
              },
              onPointerCancel: (event) {
                currentTouchPointNum =
                    (currentTouchPointNum - 1).clamp(0, 10).toInt();
                _cancelExternalDragIfAny();
                if (currentTouchPointNum == 0) {
                  _lastPointerPosition = null;
                  _evalScaleMode();
                } else if (currentTouchPointNum <= 1 &&
                    _isAtRestScale(_currentScale)) {
                  setState(() => _enablePageView = true);
                }
              },
              child: CustomDismissible(
                onDismissed: _closeWithAnimation,
                stopDrag: currentTouchPointNum > 1,
                onDismissDragStart: () {
                  widget.onDismissDragStart?.call();
                  setState(() {
                    isDismissDrag = true;
                    _enablePageView = false;
                  });
                },
                onDismissDragCancel: () {
                  widget.onDismissDragCancel?.call();
                  setState(() {
                    isDismissDrag = false;
                    _enablePageView = true;
                    _dragProgress = 0;
                  });
                },
                onDragProgress: _onDragProgress,
                enabled: widget.dismissEnabled && _enableDismiss,
                child:
                    widget.sources.length == 1 && widget.isSingle
                        ? _buildItem(context, 0, true)
                        : PageView.builder(
                          onPageChanged: _onPageChanged,
                          controller: _pageController,

                          physics:
                              _enablePageView
                                  ? null
                                  : const NeverScrollableScrollPhysics(),
                          itemCount: widget.sources.length,
                          itemBuilder: (BuildContext context, int index) {
                            return _buildItem(
                              context,
                              index,
                              index == currentIndex,
                            );
                          },
                        ),
              ),
            ),
          ),
          if (widget.showAppBar && !isDismissDrag)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: widget.appBar ?? _buildAppBar(),
            ),
          if (widget.enableIndicator &&
              !widget.isSingle &&
              widget.sources.length > 1 &&
              !isDismissDrag)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 18,
              child: _buildIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isFocus) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (TapDownDetails details) {
        _doubleTapLocalPosition = details.localPosition;
      },
      onDoubleTap: onDoubleTap,
      onTap: widget.tapToDismiss ? _closeWithAnimation : null,
      onVerticalDragStart:
          _hasExternalVerticalDrag && _isAtRestScale(_currentScale)
              ? widget.externalVerticalDragStart
              : null,
      onVerticalDragUpdate:
          _hasExternalVerticalDrag && _isAtRestScale(_currentScale)
              ? widget.externalVerticalDragUpdate
              : null,
      onVerticalDragEnd:
          _hasExternalVerticalDrag && _isAtRestScale(_currentScale)
              ? widget.externalVerticalDragEnd
              : null,
      child: widget.itemBuilder(context, index, isFocus),
    );
  }

  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.sources.length, (index) {
        final active = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.white54,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title:
          widget.isSingle
              ? null
              : Text(
                '${currentIndex! + 1} / ${widget.sources.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w400,
                ),
              ),
      automaticallyImplyLeading: false,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Center(
          child: GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: Colors.black38,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
      actions: const [SizedBox(width: 8)],
    );
  }

  void onDoubleTap() {
    Matrix4 matrix = _transformationController!.value.clone();
    double currentScale = matrix.row0.x;

    double targetScale = widget.minScale;

    if (currentScale <= widget.minScale) {
      targetScale = widget.maxScale * 0.7;
    }

    double offSetX =
        targetScale == 1.0
            ? 0.0
            : -_doubleTapLocalPosition.dx * (targetScale - 1);
    double offSetY =
        targetScale == 1.0
            ? 0.0
            : -_doubleTapLocalPosition.dy * (targetScale - 1);

    matrix = Matrix4.fromList([
      targetScale,
      matrix.row1.x,
      matrix.row2.x,
      matrix.row3.x,
      matrix.row0.y,
      targetScale,
      matrix.row2.y,
      matrix.row3.y,
      matrix.row0.z,
      matrix.row1.z,
      targetScale,
      matrix.row3.z,
      offSetX,
      offSetY,
      matrix.row2.w,
      matrix.row3.w,
    ]);

    _animation = Matrix4Tween(
      begin: _transformationController!.value,
      end: matrix,
    ).animate(CurveTween(curve: Curves.easeOut).animate(_animationController));
    _animationController
        .forward(from: 0)
        .whenComplete(() => _onScaleChanged(targetScale));
  }
}
