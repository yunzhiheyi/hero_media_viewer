import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class HeroOverlayController {
  OverlayEntry? _overlayEntry;
  VoidCallback? _animatedClose;
  VoidCallback? _onDismiss;
  bool _isShowing = false;
  final ValueNotifier<bool> _sourceHidden = ValueNotifier<bool>(false);

  bool get isShowing => _isShowing;

  // Listen with ValueListenableBuilder and wrap the source widget in
  // Visibility(visible: !hidden, maintainSize: true, ...) so it disappears
  // while the overlay flies, the same way native Hero hides its endpoints.
  ValueListenable<bool> get sourceHidden => _sourceHidden;

  void close() {
    if (!_isShowing) return;

    final close = _animatedClose;
    if (close != null) {
      close();
    } else {
      dismiss();
    }
  }

  void dismiss() {
    if (!_isShowing) return;
    final onDismiss = _onDismiss;
    if (onDismiss != null) {
      onDismiss();
      return;
    }
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _animatedClose = null;
    _isShowing = false;
    _sourceHidden.value = false;
  }
}

typedef DragCloseCallback =
    void Function(
      DragStartDetails start,
      DragUpdateDetails update,
      DragEndDetails end,
      bool isBackground,
    );

class HeroOverlayDragHandlers {
  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;

  const HeroOverlayDragHandlers({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });
}

class HeroOverlayPageIndicator extends StatelessWidget {
  final int count;
  final int index;
  final double bottomSpacing;

  const HeroOverlayPageIndicator({
    super.key,
    required this.count,
    required this.index,
    this.bottomSpacing = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + bottomSpacing,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (dotIndex) {
            final active = dotIndex == index;
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
        ),
      ),
    );
  }
}

typedef HeroOverlayCloseBuilder =
    Widget Function(BuildContext context, int index, double progress);

typedef HeroOverlayOpenBuilder =
    Widget Function(BuildContext context, int index, double progress);

typedef HeroOverlayForegroundBuilder =
    Widget Function(BuildContext context, int index);

typedef HeroOverlayTargetRectBuilder = Rect Function(int index);

typedef HeroOverlayPageBuilder =
    Widget Function(
      BuildContext context,
      HeroOverlayController controller,
      HeroOverlayDragHandlers dragHandlers,
    );

void showHeroOverlay({
  required BuildContext context,
  required Rect startRect,
  Widget Function(BuildContext context, DragCloseCallback? onDragClose)?
  builder,
  Widget Function(BuildContext context, HeroOverlayDragHandlers dragHandlers)?
  dragBuilder,
  HeroOverlayOpenBuilder? openBuilder,
  HeroOverlayCloseBuilder? closeBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
  HeroOverlayTargetRectBuilder? closeRectBuilder,
  HeroOverlayTargetRectBuilder? sharedElementTargetRectBuilder,
  Rect? targetRect,
  bool maintainChildSize = false,
  Duration openDuration = const Duration(milliseconds: 300),
  Duration closeDuration = const Duration(milliseconds: 300),
  Duration resetDuration = const Duration(milliseconds: 300),
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  VoidCallback? onClose,
  Map<int, Rect>? itemRects,
  int initialIndex = 0,
  ValueListenable<int>? currentIndexListenable,
  void Function(int index)? onIndexChanged,
  void Function(bool isDragging)? onDragStateChanged,
  bool tapToClose = true,
  bool dragToClose = true,
  bool showBackdrop = true,
  double dragBackdropOpacity = 0.0,
}) {
  final overlayController = controller ?? HeroOverlayController();

  final navigator = Navigator.maybeOf(context);
  final overlayState = Overlay.of(context);

  late OverlayEntry overlayEntry;
  _HeroSentinelRoute? sentinelRoute;
  bool cleaningUp = false;

  void cleanup() {
    if (cleaningUp) return;
    cleaningUp = true;

    if (overlayEntry.mounted) {
      overlayEntry.remove();
    }
    overlayController._overlayEntry = null;
    overlayController._animatedClose = null;
    overlayController._onDismiss = null;
    overlayController._isShowing = false;
    overlayController._sourceHidden.value = false;

    final route = sentinelRoute;
    if (route != null && route.isActive && navigator != null) {
      navigator.removeRoute(route);
    }

    onClose?.call();
  }

  overlayEntry = OverlayEntry(
    builder:
        (context) => _HeroOverlayView(
          startRect: startRect,
          aspectRatio: aspectRatio,
          fullScreen: fullScreen,
          itemRects: itemRects,
          initialIndex: initialIndex,
          currentIndexListenable: currentIndexListenable,
          onIndexChanged: onIndexChanged,
          tapToClose: tapToClose,
          dragToClose: dragToClose,
          showBackdrop: showBackdrop,
          dragBackdropOpacity: dragBackdropOpacity,
          onClose: cleanup,
          controller: overlayController,
          builder: builder,
          dragBuilder: dragBuilder,
          openBuilder: openBuilder,
          closeBuilder: closeBuilder,
          foregroundBuilder: foregroundBuilder,
          closeRectBuilder: closeRectBuilder,
          sharedElementTargetRectBuilder: sharedElementTargetRectBuilder,
          targetRect: targetRect,
          maintainChildSize: maintainChildSize,
          openDuration: openDuration,
          closeDuration: closeDuration,
          resetDuration: resetDuration,
          onDragStateChanged: onDragStateChanged,
        ),
  );

  overlayController._overlayEntry = overlayEntry;
  overlayController._isShowing = true;
  overlayController._onDismiss = cleanup;
  overlayController._sourceHidden.value = true;

  // 顺序很关键：先 push 哨兵 Route（吸收下层路由的边缘手势 + 拦物理返回），
  // 再 insert OverlayEntry。这样 z-order 上 overlay 在哨兵之上，
  // hero 自己的手势不受影响；漏掉的事件被哨兵吸收，到不了底层路由。
  if (navigator != null) {
    sentinelRoute = _HeroSentinelRoute(
      onPopRequest: overlayController.close,
      onRemoved: cleanup,
    );
    navigator.push(sentinelRoute);
  }

  overlayState.insert(overlayEntry);
}

void showHeroPageOverlay({
  required BuildContext context,
  required Rect startRect,
  required HeroOverlayPageBuilder builder,
  HeroOverlayController? controller,
  HeroOverlayOpenBuilder? openBuilder,
  HeroOverlayCloseBuilder? closeBuilder,
  HeroOverlayTargetRectBuilder? closeRectBuilder,
  HeroOverlayTargetRectBuilder? sharedElementTargetRectBuilder,
  Rect? targetRect,
  VoidCallback? onClose,
  bool tapToClose = false,
  bool dragToClose = true,
  bool showBackdrop = false,
  double dragBackdropOpacity = 0.0,
  Duration openDuration = const Duration(milliseconds: 360),
  Duration closeDuration = const Duration(milliseconds: 300),
  Duration resetDuration = const Duration(milliseconds: 260),
}) {
  final overlayController = controller ?? HeroOverlayController();
  final screenTargetRect =
      targetRect ?? (Offset.zero & MediaQuery.sizeOf(context));

  showHeroOverlay(
    context: context,
    startRect: startRect,
    targetRect: screenTargetRect,
    maintainChildSize: true,
    fullScreen: false,
    controller: overlayController,
    onClose: onClose,
    tapToClose: tapToClose,
    dragToClose: dragToClose,
    showBackdrop: showBackdrop,
    dragBackdropOpacity: dragBackdropOpacity,
    openDuration: openDuration,
    closeDuration: closeDuration,
    resetDuration: resetDuration,
    openBuilder: openBuilder,
    closeBuilder: closeBuilder,
    closeRectBuilder: closeRectBuilder,
    sharedElementTargetRectBuilder: sharedElementTargetRectBuilder,
    dragBuilder: (context, dragHandlers) {
      return builder(context, overlayController, dragHandlers);
    },
  );
}

Rect getWidgetGlobalRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderObject == null) return Rect.zero;

  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}

class _HeroOverlayView extends StatefulWidget {
  final Rect startRect;
  final Rect? targetRect;
  final bool maintainChildSize;
  final Duration openDuration;
  final Duration closeDuration;
  final Duration resetDuration;
  final double? aspectRatio;
  final bool fullScreen;
  final HeroOverlayController controller;
  final Widget Function(BuildContext context, DragCloseCallback? onDragClose)?
  builder;
  final Widget Function(
    BuildContext context,
    HeroOverlayDragHandlers dragHandlers,
  )?
  dragBuilder;
  final HeroOverlayOpenBuilder? openBuilder;
  final HeroOverlayCloseBuilder? closeBuilder;
  final HeroOverlayForegroundBuilder? foregroundBuilder;
  final HeroOverlayTargetRectBuilder? closeRectBuilder;
  final HeroOverlayTargetRectBuilder? sharedElementTargetRectBuilder;
  final VoidCallback onClose;
  final Map<int, Rect>? itemRects;
  final int initialIndex;
  final ValueListenable<int>? currentIndexListenable;
  final void Function(int index)? onIndexChanged;
  final void Function(bool isDragging)? onDragStateChanged;
  final bool tapToClose;
  final bool dragToClose;
  final bool showBackdrop;
  final double dragBackdropOpacity;

  const _HeroOverlayView({
    required this.startRect,
    required this.onClose,
    required this.controller,
    this.builder,
    this.dragBuilder,
    this.openBuilder,
    this.closeBuilder,
    this.foregroundBuilder,
    this.closeRectBuilder,
    this.sharedElementTargetRectBuilder,
    this.targetRect,
    this.maintainChildSize = false,
    this.openDuration = const Duration(milliseconds: 300),
    this.closeDuration = const Duration(milliseconds: 300),
    this.resetDuration = const Duration(milliseconds: 300),
    this.aspectRatio,
    this.fullScreen = true,
    this.itemRects,
    this.initialIndex = 0,
    this.currentIndexListenable,
    this.onIndexChanged,
    this.onDragStateChanged,
    this.tapToClose = true,
    this.dragToClose = true,
    this.showBackdrop = true,
    this.dragBackdropOpacity = 0.0,
  });

  @override
  State<_HeroOverlayView> createState() => _HeroOverlayViewState();
}

class _HeroOverlayViewState extends State<_HeroOverlayView>
    with TickerProviderStateMixin {
  AnimationController? _expandController;
  AnimationController? _dragController;

  bool _isClosing = false;
  bool _isResetting = false;
  bool _initialized = false;

  late Rect _startRect;
  late Rect _targetRect;
  late Size _screenSize;
  late double _aspectRatio;
  late int _currentIndex;

  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;
  double _dragScale = 1.0;
  double _startOpacity = 1.0;
  double _closeAnimValue = 0.0;
  double _resetStartOpacity = 1.0;
  double _resetStartForegroundOpacity = 1.0;
  double _resetAnimValue = 0.0;

  double _pivotX = 0.5;
  double _pivotY = 0.5;
  bool _pivotSet = false;

  Rect? _closeStartRect;
  Rect? _resetStartRect;
  Offset? _lastDragGlobalPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _screenSize = MediaQuery.of(context).size;
      _startRect = widget.startRect;
      _aspectRatio = widget.aspectRatio ?? (16.0 / 9.0);
      _currentIndex = widget.initialIndex;
      _calculateTargetRect(_aspectRatio);
      _initAnimations();
      widget.controller._animatedClose = _close;
      widget.currentIndexListenable?.addListener(_handleCurrentIndexChanged);
    }
  }

  void _handleCurrentIndexChanged() {
    updateCurrentIndex(widget.currentIndexListenable!.value);
  }

  void _calculateTargetRect(double aspectRatio) {
    _aspectRatio = aspectRatio;

    if (widget.targetRect != null) {
      _targetRect = widget.targetRect!;
      return;
    }

    if (widget.fullScreen) {
      _targetRect = Offset.zero & _screenSize;
    } else {
      double targetWidth = _screenSize.width;
      double targetHeight = targetWidth / aspectRatio;

      if (targetHeight > _screenSize.height) {
        targetHeight = _screenSize.height;
        targetWidth = targetHeight * aspectRatio;
      }

      _targetRect = Rect.fromCenter(
        center: Offset(_screenSize.width / 2, _screenSize.height / 2),
        width: targetWidth,
        height: targetHeight,
      );
    }
  }

  void _initAnimations() {
    _expandController = AnimationController(
      duration: widget.openDuration,
      vsync: this,
    );

    _dragController = AnimationController(
      duration: widget.closeDuration,
      vsync: this,
    );

    _expandController!.forward();
  }

  void _handleDragStart(DragStartDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;

    widget.onDragStateChanged?.call(true);
    _lastDragGlobalPosition = details.globalPosition;

    if (!_pivotSet) {
      _pivotSet = true;
      final currentRect = _getCurrentRect();
      final fingerGlobal = details.globalPosition;
      _pivotX = (fingerGlobal.dx - currentRect.left) / currentRect.width;
      _pivotY = (fingerGlobal.dy - currentRect.top) / currentRect.height;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;

    var delta = details.delta;
    final lastPosition = _lastDragGlobalPosition;

    if (lastPosition != null) {
      final globalDelta = details.globalPosition - lastPosition;
      if (globalDelta.distanceSquared > 0) {
        delta = globalDelta;
      }
    }

    _lastDragGlobalPosition = details.globalPosition;
    _dragOffsetX += delta.dx;
    _dragOffsetY += delta.dy;

    if (_dragOffsetY > 0) {
      _dragScale = 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 0.5);
    } else {
      _dragScale = 1.0;
    }

    setState(() {});
  }

  void _handleDragEnd(DragEndDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;

    widget.onDragStateChanged?.call(false);
    _lastDragGlobalPosition = null;

    const threshold = 100.0;
    final velocity = details.velocity.pixelsPerSecond.dy;

    if (_dragOffsetY > threshold || velocity > 500) {
      _closeWithDrag();
    } else {
      _resetDrag();
    }
  }

  DragCloseCallback _createDragCloseCallback() {
    return (start, update, end, isBackground) {
      if (isBackground) {
        _pivotX = 0.5;
        _pivotY = 0.5;
        _pivotSet = true;
      }
      _handleDragStart(start, isBackground);
      _handleDragUpdate(update, isBackground);
      _handleDragEnd(end, isBackground);
    };
  }

  HeroOverlayDragHandlers _createDragHandlers() {
    return HeroOverlayDragHandlers(
      onStart: (details) => _handleDragStart(details, false),
      onUpdate: (details) => _handleDragUpdate(details, false),
      onEnd: (details) => _handleDragEnd(details, false),
    );
  }

  Rect _getCurrentRect() {
    final t = _expandController?.value ?? 0.0;
    return Rect.lerp(_startRect, _targetRect, t)!;
  }

  Rect _getDraggedRect() {
    final currentRect = _getCurrentRect();
    final currentWidth = currentRect.width * _dragScale;
    final currentHeight = currentRect.height * _dragScale;
    final currentLeft =
        currentRect.left +
        (currentRect.width - currentWidth) * _pivotX +
        _dragOffsetX;
    final currentTop =
        currentRect.top +
        (currentRect.height - currentHeight) * _pivotY +
        _dragOffsetY;

    return Rect.fromLTWH(currentLeft, currentTop, currentWidth, currentHeight);
  }

  void updateCurrentIndex(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
        if (widget.itemRects != null && widget.itemRects!.containsKey(index)) {
          _startRect = widget.itemRects![index]!;
        }
      });
      widget.onIndexChanged?.call(index);
    }
  }

  Rect _getCloseTargetRect() {
    final builderRect = widget.closeRectBuilder?.call(_currentIndex);
    if (_isValidRect(builderRect)) {
      return builderRect!;
    }

    if (widget.itemRects != null &&
        widget.itemRects!.containsKey(_currentIndex)) {
      final mapRect = widget.itemRects![_currentIndex]!;
      if (_isValidRect(mapRect)) {
        return mapRect;
      }
    }

    if (_isValidRect(_startRect)) {
      return _startRect;
    }

    // Source widget is gone (scrolled off-screen, disposed, or never measured).
    // Collapse in place instead of flying to (0,0).
    return _closeStartRect ?? _targetRect;
  }

  bool _isValidRect(Rect? rect) {
    if (rect == null || rect.isEmpty) return false;
    if (rect.right <= 0 || rect.bottom <= 0) return false;
    if (rect.left >= _screenSize.width || rect.top >= _screenSize.height) {
      return false;
    }
    return true;
  }

  void _closeWithDrag() {
    if (_isClosing) return;
    _isClosing = true;

    _closeStartRect = _getDraggedRect();

    final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _startOpacity = 1.0 - dragProgress;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: widget.closeDuration,
      vsync: this,
    );

    final curve = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    curve.addListener(() {
      setState(() {
        _closeAnimValue = curve.value;
      });
    });

    curve.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onClose();
      }
    });

    _dragController!.forward();
  }

  void _resetDrag() {
    if (_isResetting) return;

    _isResetting = true;
    _resetStartRect = _getDraggedRect();
    _resetAnimValue = 0.0;

    final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _resetStartOpacity = 1.0 - dragProgress;
    _resetStartForegroundOpacity = _foregroundOpacityFromDragOffset();

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: widget.resetDuration,
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    animation.addListener(() {
      setState(() {
        _resetAnimValue = animation.value;
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        setState(() {
          _isResetting = false;
          _resetStartRect = null;
          _resetAnimValue = 0.0;
          _resetStartOpacity = 1.0;
          _resetStartForegroundOpacity = 1.0;
          _dragOffsetX = 0;
          _dragOffsetY = 0;
          _dragScale = 1.0;
          _lastDragGlobalPosition = null;
        });
        _pivotSet = false;
      }
    });

    _dragController!.forward();
  }

  void _close() async {
    if (_isClosing) return;
    _isClosing = true;

    final closeTarget = _getCloseTargetRect();
    final targetAspect = closeTarget.width / closeTarget.height;

    final currentRect = _getCurrentRect();
    final currentAspect = currentRect.width / currentRect.height;

    if ((targetAspect - currentAspect).abs() > 0.01) {
      final adjustedHeight = currentRect.width / targetAspect;
      final adjustedY = currentRect.center.dy - adjustedHeight / 2;
      _closeStartRect = Rect.fromLTWH(
        currentRect.left,
        adjustedY,
        currentRect.width,
        adjustedHeight,
      );
    } else {
      _closeStartRect = currentRect;
    }

    _startOpacity = 1.0;
    _dragScale = 1.0;
    _dragOffsetX = 0;
    _dragOffsetY = 0;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: widget.closeDuration,
      vsync: this,
    );

    final curve = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    curve.addListener(() {
      setState(() {
        _closeAnimValue = curve.value;
      });
    });

    curve.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onClose();
      }
    });

    _dragController!.forward();
  }

  @override
  void dispose() {
    widget.currentIndexListenable?.removeListener(_handleCurrentIndexChanged);
    if (widget.controller._animatedClose == _close) {
      widget.controller._animatedClose = null;
    }
    _expandController?.dispose();
    _dragController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _expandController == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          if (widget.showBackdrop || widget.dragBackdropOpacity > 0)
            GestureDetector(
              onTap:
                  widget.tapToClose && !_isClosing && _dragOffsetY < 10
                      ? _close
                      : null,
              onPanStart:
                  widget.dragToClose ? (d) => _handleDragStart(d, true) : null,
              onPanUpdate:
                  widget.dragToClose ? (d) => _handleDragUpdate(d, true) : null,
              onPanEnd:
                  widget.dragToClose ? (d) => _handleDragEnd(d, true) : null,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _expandController,
                  _dragController,
                ]),
                builder: (context, child) {
                  final opacity =
                      widget.showBackdrop
                          ? _fullBackdropOpacity()
                          : _dragOnlyBackdropOpacity();

                  return Container(
                    color: Colors.black.withValues(alpha: opacity),
                    width: double.infinity,
                    height: double.infinity,
                  );
                },
              ),
            ),
          AnimatedBuilder(
            animation: Listenable.merge([_expandController, _dragController]),
            builder: (context, child) {
              Rect rect;

              if (_isResetting && _resetStartRect != null) {
                rect =
                    Rect.lerp(_resetStartRect!, _targetRect, _resetAnimValue)!;
              } else if (_isClosing && _closeStartRect != null) {
                final closeTarget = _getCloseTargetRect();
                final targetAspect = closeTarget.width / closeTarget.height;
                final currentAspect =
                    _closeStartRect!.width / _closeStartRect!.height;

                Rect startRect = _closeStartRect!;

                if ((targetAspect - currentAspect).abs() > 0.1) {
                  final startHeight = startRect.width / targetAspect;
                  final startY = startRect.center.dy - startHeight / 2;
                  startRect = Rect.fromLTWH(
                    startRect.left,
                    startY,
                    startRect.width,
                    startHeight,
                  );
                }

                rect = Rect.lerp(startRect, closeTarget, _closeAnimValue)!;
              } else {
                final t = _expandController!.value;
                final baseRect = Rect.lerp(_startRect, _targetRect, t)!;
                final width = baseRect.width * _dragScale;
                final height = baseRect.height * _dragScale;
                final left =
                    baseRect.left +
                    (baseRect.width - width) * _pivotX +
                    _dragOffsetX;
                final top =
                    baseRect.top +
                    (baseRect.height - height) * _pivotY +
                    _dragOffsetY;

                rect = Rect.fromLTWH(left, top, width, height);
              }

              return _buildAnimatedOverlayChild(context, rect, child!);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child:
                  widget.dragBuilder?.call(context, _createDragHandlers()) ??
                  widget.builder?.call(context, _createDragCloseCallback()) ??
                  const SizedBox.shrink(),
            ),
          ),
          AnimatedBuilder(
            animation: Listenable.merge([_expandController, _dragController]),
            builder: (context, child) {
              if (_expandController!.value < 0.5 || _isClosing) {
                return const SizedBox.shrink();
              }
              final opacity = 1.0 - (_dragOffsetY / 100).clamp(0.0, 1.0);
              return Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                left: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _close,
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          if (!_isClosing && widget.foregroundBuilder != null)
            AnimatedBuilder(
              animation: Listenable.merge([_expandController, _dragController]),
              builder: (context, child) {
                return Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _foregroundOpacity(),
                      child: Stack(
                        children: [
                          widget.foregroundBuilder!(context, _currentIndex),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  double _fullBackdropOpacity() {
    final t = _expandController!.value;
    if (_isClosing && _closeStartRect != null) {
      return _startOpacity * (1.0 - _closeAnimValue);
    }
    if (_isResetting) {
      return _resetStartOpacity +
          (1.0 - _resetStartOpacity) * _resetAnimValue;
    }
    if (_isClosing) {
      return t;
    }
    if (t < 1.0) {
      return t;
    }
    if (_dragOffsetY > 0) {
      final dragProgress =
          (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
      return 1.0 - dragProgress;
    }
    return 1.0;
  }

  double _dragOnlyBackdropOpacity() {
    final max = widget.dragBackdropOpacity.clamp(0.0, 1.0);
    if (max <= 0) return 0.0;

    final dragProgress =
        (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    final dragOpacity = dragProgress * max;

    if (_isClosing && _closeStartRect != null) {
      return dragOpacity * (1.0 - _closeAnimValue);
    }
    if (_isResetting) {
      return dragOpacity * (1.0 - _resetAnimValue);
    }
    return dragOpacity;
  }

  double _foregroundOpacity() {
    final expandOpacity = ((_expandController?.value ?? 0.0) * 2).clamp(
      0.0,
      1.0,
    );

    if (_isResetting) {
      return (_resetStartForegroundOpacity +
              (1.0 - _resetStartForegroundOpacity) * _resetAnimValue)
          .clamp(0.0, 1.0);
    }

    return (expandOpacity * _foregroundOpacityFromDragOffset()).clamp(0.0, 1.0);
  }

  double _foregroundOpacityFromDragOffset() {
    const fadeDistance = 120.0;
    if (_dragOffsetY <= 0) {
      return 1.0;
    }
    return (1.0 - (_dragOffsetY / fadeDistance).clamp(0.0, 1.0)).clamp(
      0.0,
      1.0,
    );
  }

  Widget _buildAnimatedOverlayChild(
    BuildContext context,
    Rect rect,
    Widget child,
  ) {
    final usesSharedElement = widget.sharedElementTargetRectBuilder != null;
    final enableOuterDrag = widget.dragToClose && !usesSharedElement;
    final overlayChild = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap:
          widget.tapToClose && !_isClosing && _dragOffsetY < 10 ? _close : null,
      onVerticalDragStart:
          enableOuterDrag ? (d) => _handleDragStart(d, false) : null,
      onVerticalDragUpdate:
          enableOuterDrag ? (d) => _handleDragUpdate(d, false) : null,
      onVerticalDragEnd:
          enableOuterDrag ? (d) => _handleDragEnd(d, false) : null,
      child: usesSharedElement ? child : _buildOverlayContent(context, child),
    );

    if (!widget.maintainChildSize) {
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: overlayChild,
      );
    }

    if (widget.sharedElementTargetRectBuilder != null) {
      return _buildSharedElementPageTransition(rect, overlayChild);
    }

    final detailOpacity = _maintainedDetailOpacity();
    final transitionPreview = _buildMaintainedTransitionPreview(rect);

    return Stack(
      children: [
        if (transitionPreview != null) transitionPreview,
        Positioned(
          left: _targetRect.left,
          top: _targetRect.top,
          width: _targetRect.width,
          height: _targetRect.height,
          child: Opacity(
            opacity: detailOpacity,
            child: _buildMaintainedTransform(rect, overlayChild),
          ),
        ),
      ],
    );
  }

  Widget _buildSharedElementPageTransition(Rect rect, Widget child) {
    final detailOpacity = _sharedElementDetailOpacity();
    final transitionPreview = _buildSharedElementTransitionPreview(rect);
    final detailChild = _buildMaintainedTransform(rect, child);

    return Stack(
      children: [
        Positioned(
          left: _targetRect.left,
          top: _targetRect.top,
          width: _targetRect.width,
          height: _targetRect.height,
          child: Opacity(opacity: detailOpacity, child: detailChild),
        ),
        if (transitionPreview != null) transitionPreview,
      ],
    );
  }

  Widget _buildMaintainedTransform(Rect rect, Widget child) {
    final scaleX =
        _targetRect.width == 0 ? 1.0 : rect.width / _targetRect.width;
    final scaleY =
        _targetRect.height == 0 ? 1.0 : rect.height / _targetRect.height;

    return Transform.translate(
      offset: Offset(rect.left - _targetRect.left, rect.top - _targetRect.top),
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scaleX: scaleX,
        scaleY: scaleY,
        child: SizedBox(
          width: _targetRect.width,
          height: _targetRect.height,
          child: child,
        ),
      ),
    );
  }

  Widget? _buildMaintainedTransitionPreview(Rect rect) {
    final opening =
        !_isClosing && !_isResetting && _expandController!.value < 1;
    final closing = _isClosing && _closeStartRect != null;

    final Widget? preview;
    final double opacity;

    if (opening && widget.openBuilder != null) {
      final progress = _expandController!.value.clamp(0.0, 1.0);
      preview = widget.openBuilder!(context, _currentIndex, progress);
      opacity = 1.0 - _interval(progress, 0.32, 0.70);
    } else if (closing && widget.closeBuilder != null) {
      final progress = _closeAnimValue.clamp(0.0, 1.0);
      preview = widget.closeBuilder!(context, _currentIndex, progress);
      opacity = _interval(progress, 0.10, 0.62);
    } else {
      return null;
    }

    if (opacity <= 0) {
      return null;
    }

    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: IgnorePointer(
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: preview),
      ),
    );
  }

  Widget? _buildSharedElementTransitionPreview(Rect rect) {
    final opening =
        !_isClosing && !_isResetting && _expandController!.value < 1;
    final closing = _isClosing && _closeStartRect != null;

    final Widget? preview;
    final Rect previewRect;
    final double opacity;
    final target = _getSharedElementTargetRect();

    if (opening && widget.openBuilder != null) {
      final progress = _expandController!.value.clamp(0.0, 1.0);
      preview = widget.openBuilder!(context, _currentIndex, progress);
      previewRect = Rect.lerp(_startRect, target, progress)!;
      opacity = 1.0 - _interval(progress, 0.80, 0.96);
    } else if (closing && widget.closeBuilder != null) {
      final progress = _closeAnimValue.clamp(0.0, 1.0);
      final start = _dragOffsetY > 0 ? (_closeStartRect ?? target) : target;
      final end = _getCloseTargetRect();
      preview = widget.closeBuilder!(context, _currentIndex, progress);
      previewRect = Rect.lerp(start, end, progress)!;
      opacity = _interval(progress, 0.0, 0.16);
    } else if (!_isClosing && !_isResetting && widget.openBuilder != null) {
      preview = widget.openBuilder!(context, _currentIndex, 1.0);
      previewRect = target;
      opacity = 0.0;
    } else {
      return null;
    }

    if (opacity <= 0) {
      return null;
    }

    return Positioned(
      left: previewRect.left,
      top: previewRect.top,
      width: previewRect.width,
      height: previewRect.height,
      child: IgnorePointer(
        child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: preview),
      ),
    );
  }

  Rect _getSharedElementTargetRect() {
    final rect = widget.sharedElementTargetRectBuilder?.call(_currentIndex);
    if (rect != null && !rect.isEmpty) {
      return rect;
    }
    return _targetRect;
  }

  double _sharedElementDetailOpacity() {
    if (_isClosing && _closeStartRect != null && widget.closeBuilder != null) {
      return (1.0 - _interval(_closeAnimValue, 0.04, 0.30)).clamp(0.0, 1.0);
    }

    if (_dragOffsetY > 0 && !_isClosing && !_isResetting) {
      final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
      return (1.0 - dragProgress * 0.35).clamp(0.0, 1.0);
    }

    if (!_isClosing && !_isResetting && widget.openBuilder != null) {
      return _interval(_expandController!.value, 0.80, 0.96);
    }

    return 1.0;
  }

  double _maintainedDetailOpacity() {
    if (_isClosing && _closeStartRect != null && widget.closeBuilder != null) {
      return (1.0 - _interval(_closeAnimValue, 0.0, 0.42)).clamp(0.0, 1.0);
    }

    if (!_isClosing && !_isResetting && widget.openBuilder != null) {
      return _interval(_expandController!.value, 0.36, 0.76);
    }

    return 1.0;
  }

  double _interval(double value, double start, double end) {
    if (value <= start) {
      return 0.0;
    }
    if (value >= end) {
      return 1.0;
    }
    return Curves.easeOutCubic.transform((value - start) / (end - start));
  }

  Widget _buildOverlayContent(BuildContext context, Widget child) {
    if (!_isClosing || _closeStartRect == null || widget.closeBuilder == null) {
      return child;
    }

    final progress = _closeAnimValue.clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        Opacity(opacity: 1.0 - progress, child: child),
        Opacity(
          opacity: progress,
          child: widget.closeBuilder!(context, _currentIndex, progress),
        ),
      ],
    );
  }
}

abstract class HeroOverlayViewState {
  void updateCurrentIndex(int index);
}

/// 哨兵 Route：与 hero overlay 配对推入 Navigator。
///
/// 职责：
/// 1. PopScope(canPop:false) 拦截 Android 物理返回键 + Android 14 预测式返回手势 →
///    走自定义关闭动画而不是直接 pop。
/// 2. 全屏 AbsorbPointer 吸收下层路由的边缘手势（iOS 左滑返回），让
///    CupertinoPageRoute 的 _CupertinoBackGestureDetector 拿不到 touch。
/// 3. dispose 时回调 onRemoved，保证外部 popUntil/removeRoute 等场景下
///    overlay entry 也能被清掉。
class _HeroSentinelRoute<T> extends PageRouteBuilder<T> {
  final VoidCallback onPopRequest;
  final VoidCallback onRemoved;
  bool _onRemovedFired = false;

  _HeroSentinelRoute({required this.onPopRequest, required this.onRemoved})
    : super(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        maintainState: true,
        pageBuilder: (_, _, _) => const SizedBox.shrink(),
      );

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onPopRequest();
      },
      child: const AbsorbPointer(
        absorbing: true,
        child: SizedBox.expand(),
      ),
    );
  }

  @override
  void dispose() {
    if (!_onRemovedFired) {
      _onRemovedFired = true;
      onRemoved();
    }
    super.dispose();
  }
}
