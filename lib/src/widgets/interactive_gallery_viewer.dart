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
    this.minScale = 0.6,
    this.onPageChanged,
    this.isSingle = false,
    this.enableIndicator = false,
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
  final VoidCallback? onDismissDragStart;
  final VoidCallback? onDismissDragCancel;

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

  void _onScaleChanged(double scale) {
    final bool initialScale = scale <= widget.minScale;
    if (initialScale) {
      if (!_enableDismiss) {
        setState(() {
          _enableDismiss = true;
        });
      }

      if (!_enablePageView) {
        setState(() {
          _enablePageView = true;
        });
      }
    } else {
      if (_enableDismiss) {
        setState(() {
          _enableDismiss = false;
        });
      }

      if (_enablePageView) {
        setState(() {
          _enablePageView = false;
        });
      }
      if (scale == 1.0) {
        setState(() {
          _enableDismiss = true;
        });
        return;
      }
    }
  }

  void _onLeftBoundaryHit() {
    if (_pageController != null &&
        _pageController!.hasClients &&
        !_enablePageView &&
        _pageController!.page != null &&
        _pageController!.page!.floor() > 0 &&
        !widget.isSingle) {
      setState(() {
        _enablePageView = true;
      });
    }
  }

  void _onRightBoundaryHit() {
    if (_pageController != null &&
        _pageController!.hasClients &&
        !_enablePageView &&
        _pageController!.page != null &&
        _pageController!.page!.floor() < widget.sources.length - 1 &&
        !widget.isSingle) {
      setState(() {
        _enablePageView = true;
      });
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
    });
    widget.onPageChanged?.call(page);
    if (_transformationController!.value != Matrix4.identity()) {
      _animation = Matrix4Tween(
        begin: _transformationController!.value,
        end: Matrix4.identity(),
      ).animate(
        CurveTween(curve: Curves.easeOut).animate(_animationController),
      );
      _animationController.forward(from: 0);
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
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - _dragProgress).clamp(0.0, 1.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
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
            scaleEnabled: true,
            child: Listener(
              onPointerDown: (event) {
                currentTouchPointNum++;
                if (currentTouchPointNum > 1) {
                  setState(() {
                    _enablePageView = false;
                  });
                }
              },
              onPointerUp: (event) {
                currentTouchPointNum--;
                if (currentTouchPointNum <= 1) {
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
                enabled: _enableDismiss,
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
          if (!isDismissDrag)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: widget.appBar ?? _buildAppBar(),
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index, bool isFocus) {
    return GestureDetector(
      onDoubleTapDown: (TapDownDetails details) {
        _doubleTapLocalPosition = details.localPosition;
      },
      onTap: _closeWithAnimation,
      child: widget.itemBuilder(context, index, isFocus),
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
