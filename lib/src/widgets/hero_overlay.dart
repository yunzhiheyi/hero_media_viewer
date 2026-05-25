import 'package:flutter/material.dart';

class HeroOverlayController {
  OverlayEntry? _overlayEntry;
  bool _isShowing = false;

  bool get isShowing => _isShowing;

  void dismiss() {
    if (_overlayEntry != null && _isShowing) {
      _overlayEntry!.remove();
      _overlayEntry = null;
      _isShowing = false;
    }
  }
}

typedef DragCloseCallback =
    void Function(
      DragStartDetails start,
      DragUpdateDetails update,
      DragEndDetails end,
      bool isBackground,
    );

void showHeroOverlay({
  required BuildContext context,
  required Rect startRect,
  required Widget Function(BuildContext context, DragCloseCallback? onDragClose)
  builder,
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  VoidCallback? onClose,
  Map<int, Rect>? itemRects,
  int initialIndex = 0,
  void Function(int index)? onIndexChanged,
  void Function(bool isDragging)? onDragStateChanged,
}) {
  final overlayController = controller ?? HeroOverlayController();

  late OverlayEntry overlayEntry;

  overlayEntry = OverlayEntry(
    builder:
        (context) => _HeroOverlayView(
          startRect: startRect,
          aspectRatio: aspectRatio,
          fullScreen: fullScreen,
          itemRects: itemRects,
          initialIndex: initialIndex,
          onIndexChanged: onIndexChanged,
          onClose: () {
            overlayEntry.remove();
            overlayController._overlayEntry = null;
            overlayController._isShowing = false;
            onClose?.call();
          },
          builder: builder,
          onDragStateChanged: onDragStateChanged,
        ),
  );

  overlayController._overlayEntry = overlayEntry;
  overlayController._isShowing = true;
  Overlay.of(context).insert(overlayEntry);
}

Rect getWidgetGlobalRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderObject == null) return Rect.zero;

  final offset = renderObject.localToGlobal(Offset.zero);
  return offset & renderObject.size;
}

class _HeroOverlayView extends StatefulWidget {
  final Rect startRect;
  final double? aspectRatio;
  final bool fullScreen;
  final Widget Function(BuildContext context, DragCloseCallback? onDragClose)
  builder;
  final VoidCallback onClose;
  final Map<int, Rect>? itemRects;
  final int initialIndex;
  final void Function(int index)? onIndexChanged;
  final void Function(bool isDragging)? onDragStateChanged;

  const _HeroOverlayView({
    required this.startRect,
    required this.builder,
    required this.onClose,
    this.aspectRatio,
    this.fullScreen = true,
    this.itemRects,
    this.initialIndex = 0,
    this.onIndexChanged,
    this.onDragStateChanged,
  });

  @override
  State<_HeroOverlayView> createState() => _HeroOverlayViewState();
}

class _HeroOverlayViewState extends State<_HeroOverlayView>
    with TickerProviderStateMixin {
  AnimationController? _expandController;
  AnimationController? _dragController;

  bool _isClosing = false;
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

  double _pivotX = 0.5;
  double _pivotY = 0.5;
  bool _pivotSet = false;

  Rect? _closeStartRect;

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
    }
  }

  void _calculateTargetRect(double aspectRatio) {
    _aspectRatio = aspectRatio;

    if (widget.fullScreen) {
      final padding = MediaQuery.of(context).padding;
      final safeHeight = _screenSize.height - padding.top - padding.bottom - 32;

      _targetRect = Rect.fromCenter(
        center: Offset(_screenSize.width / 2, _screenSize.height / 2),
        width: _screenSize.width,
        height: safeHeight,
      );
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
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _dragController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );

    _expandController!.forward();
  }

  void _handleDragStart(DragStartDetails details, bool isBackground) {
    if (_isClosing) return;

    widget.onDragStateChanged?.call(true);

    if (!_pivotSet) {
      _pivotSet = true;
      final currentRect = _getCurrentRect();
      final fingerGlobal = details.globalPosition;
      _pivotX = (fingerGlobal.dx - currentRect.left) / currentRect.width;
      _pivotY = (fingerGlobal.dy - currentRect.top) / currentRect.height;
    }
  }

  void _handleDragUpdate(DragUpdateDetails details, bool isBackground) {
    if (_isClosing) return;

    _dragOffsetX += details.delta.dx;
    _dragOffsetY += details.delta.dy;

    if (_dragOffsetY > 0) {
      _dragScale = 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 0.5);
    } else {
      _dragScale = 1.0;
    }

    setState(() {});
  }

  void _handleDragEnd(DragEndDetails details, bool isBackground) {
    if (_isClosing) return;

    widget.onDragStateChanged?.call(false);

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

  Rect _getCurrentRect() {
    final t = _expandController?.value ?? 0.0;
    return Rect.lerp(_startRect, _targetRect, t)!;
  }

  void updateCurrentIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      if (widget.itemRects != null && widget.itemRects!.containsKey(index)) {
        _startRect = widget.itemRects![index]!;
      }
      widget.onIndexChanged?.call(index);
    }
  }

  Rect _getCloseTargetRect() {
    if (widget.itemRects != null &&
        widget.itemRects!.containsKey(_currentIndex)) {
      return widget.itemRects![_currentIndex]!;
    }
    return _startRect;
  }

  void _closeWithDrag() {
    if (_isClosing) return;
    _isClosing = true;

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

    _closeStartRect = Rect.fromLTWH(
      currentLeft,
      currentTop,
      currentWidth,
      currentHeight,
    );

    final dragProgress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _startOpacity = 1.0 - dragProgress;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
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
    final startOffsetX = _dragOffsetX;
    final startOffsetY = _dragOffsetY;
    final startScale = _dragScale;

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    final animation = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    animation.addListener(() {
      setState(() {
        _dragOffsetX = startOffsetX * (1 - animation.value);
        _dragOffsetY = startOffsetY * (1 - animation.value);
        _dragScale = 1.0 - (1.0 - startScale) * (1 - animation.value);
      });
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
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
      duration: const Duration(milliseconds: 300),
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
          GestureDetector(
            onTap: !_isClosing && _dragOffsetY < 10 ? _close : null,
            onPanStart: (d) => _handleDragStart(d, true),
            onPanUpdate: (d) => _handleDragUpdate(d, true),
            onPanEnd: (d) => _handleDragEnd(d, true),
            child: AnimatedBuilder(
              animation: Listenable.merge([_expandController, _dragController]),
              builder: (context, child) {
                final t = _expandController!.value;
                var opacity = 1.0;

                if (_isClosing && _closeStartRect != null) {
                  opacity = _startOpacity * (1.0 - _closeAnimValue);
                } else if (_isClosing) {
                  opacity = t;
                } else if (t < 1.0) {
                  opacity = t;
                } else if (_dragOffsetY > 0) {
                  final dragProgress = (_dragOffsetY / _screenSize.height)
                      .clamp(0.0, 1.0);
                  opacity = 1.0 - dragProgress;
                }

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

              if (_isClosing && _closeStartRect != null) {
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

              return Positioned(
                left: rect.left,
                top: rect.top,
                width: rect.width,
                height: rect.height,
                child: child!,
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.zero,
              child: widget.builder(context, _createDragCloseCallback()),
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
        ],
      ),
    );
  }
}

abstract class HeroOverlayViewState {
  void updateCurrentIndex(int index);
}
