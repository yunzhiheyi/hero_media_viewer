import 'package:flutter/material.dart';

import 'custom_dismissible.dart';
import 'interactive_viewer_boundary.dart';

/// `(context, index, isFocus)` 形式的列表项构造器签名，与 [PageView.builder] 协作。
typedef IndexedFocusedWidgetBuilder = Widget Function(
  BuildContext context,
  int index,
  bool isFocus,
);

/// rest 状态阈值：scale ≤ 1.01 视为没放大，开启翻页 / 下滑关闭。
const double _kRestScaleEpsilon = 1.01;

/// zoom 状态下把"贴边继续下拖"转成关闭手势所需的累计位移（像素）。
/// 必须足够大：平移与关闭的意图区分靠它，太小会让正常平移误触关闭。
const double _kOverPanStartDistance = 12.0;

/// 判定矩阵 translation 是否贴住边界的容差（像素）。
const double _kBoundaryEpsilon = 2.0;

/// 缩放 + 翻页 + 下滑关闭一体化的画廊容器。
///
/// 集成：[InteractiveViewer] 双指缩放 + [PageView] 左右翻页 + [CustomDismissible] 下滑关闭，
/// 并通过 `externalVerticalDrag*` 把下滑事件转交给外层（hero overlay 的关闭回位动画）。
///
/// 关键交互规则：
/// 1. **rest scale**：1 指下滑 → 触发关闭；2 指 → pinch 放大。
/// 2. **zoom scale**：1 指 → 平移；图片到顶/底边界后继续向下拖 → 转为关闭手势。
/// 3. **2 指落下**：立即取消 1 指阶段已经吃下的拖动，避免 pinch 焦点漂移。
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

  /// 数据源列表（任意类型，由 [itemBuilder] 自行渲染）。
  final List<T> sources;

  /// 初始页索引。
  final int initIndex;

  /// 单项渲染器：(context, index, isFocus)。
  final IndexedFocusedWidgetBuilder itemBuilder;

  /// 单图模式开关：true 时不使用 PageView。
  final bool isSingle;

  /// 是否显示底部页码指示点。
  final bool enableIndicator;

  /// 自定义 AppBar；为空时使用内置关闭按钮 + 页码标题。
  final Widget? appBar;

  /// 最大 / 最小缩放比例（透传给 [InteractiveViewer]）。
  final double maxScale;
  final double minScale;

  /// 翻页回调。
  final ValueChanged<int>? onPageChanged;

  /// 关闭请求回调；为空时直接 `Navigator.of(context).pop()`。
  final VoidCallback? onCloseRequested;

  /// 下拖关闭开始/取消回调。
  final VoidCallback? onDismissDragStart;
  final VoidCallback? onDismissDragCancel;

  /// 是否显示黑色背景层。
  final bool showBackground;

  /// 是否显示 AppBar。
  final bool showAppBar;

  /// 是否启用单击关闭。
  final bool tapToDismiss;

  /// 是否启用内置 [CustomDismissible] 下拖关闭。
  final bool dismissEnabled;

  /// 三个外部下拖事件回调：当全部提供时，rest 状态的下拖会被路由给外部
  /// （hero overlay 用于关闭回位动画）；缺一即视为不启用。
  final GestureDragStartCallback? externalVerticalDragStart;
  final GestureDragUpdateCallback? externalVerticalDragUpdate;
  final GestureDragEndCallback? externalVerticalDragEnd;

  @override
  State<InteractiveGalleryViewer> createState() =>
      _InteractiveGalleryViewerState();
}

class _InteractiveGalleryViewerState extends State<InteractiveGalleryViewer>
    with TickerProviderStateMixin {
  // ─── controllers ─────────────────────────────────────────────────────────
  PageController? _pageController;
  final _transformController = TransformationController();
  late final AnimationController _doubleTapAnim;
  Animation<Matrix4>? _doubleTapAnimation;

  // ─── ui state ────────────────────────────────────────────────────────────
  int? currentIndex;
  bool _enablePageView = true;
  bool _enableDismiss = true;
  bool isDismissDrag = false;
  double _dragProgress = 0;

  // ─── gesture tracking ────────────────────────────────────────────────────
  int currentTouchPointNum = 0;
  double _currentScale = 1.0;
  late Offset _doubleTapLocalPosition;

  /// zoom 状态下"过拖（over-pan）转下滑关闭"的状态机：
  /// 只有图片顶边已贴住视口顶部（矩阵被 clamp、无法再向下平移）时，继续
  /// 向下的拖动才累计为过拖；累计超过 [_kOverPanStartDistance] 才转交外部
  /// drag。不再用"指针位移 vs 矩阵位移差"推断——pointer 事件与矩阵更新
  /// 存在一帧时差，快速平移时会得出虚假丢失量而误触关闭。
  Offset? _lastPointerPosition;
  double _overPanAccumY = 0;
  bool _externalDragActive = false;

  /// rest 状态下 1 指 dismiss drag 是否已激活；2 指落下时用它来取消已触发的拖动。
  bool _externalDismissDragActive = false;

  bool get _gestureInProgress => currentTouchPointNum > 0;

  bool get _hasExternalVerticalDrag =>
      widget.externalVerticalDragStart != null &&
      widget.externalVerticalDragUpdate != null &&
      widget.externalVerticalDragEnd != null;

  bool _isAtRest(double scale) => scale <= _kRestScaleEpsilon;

  // ─── lifecycle ───────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    if (!widget.isSingle) {
      _pageController = PageController(initialPage: widget.initIndex);
    }
    _doubleTapAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )
      ..addListener(() {
        _transformController.value =
            _doubleTapAnimation?.value ?? Matrix4.identity();
      })
      ..addStatusListener((status) {
        // 双击缩放动画结束后按"当前 scale"重算手势模式：放大后必须保持
        // 下滑关闭禁用，之前无条件重新启用会让放大态单指拖动误触关闭。
        if (status == AnimationStatus.completed) {
          _evalScaleMode();
        }
      });
    currentIndex = widget.initIndex;
  }

  @override
  void dispose() {
    _pageController?.dispose();
    _transformController.dispose();
    _doubleTapAnim.dispose();
    super.dispose();
  }

  // ─── scale state machine ─────────────────────────────────────────────────
  /// scale 实时回调；手势中不重建 InteractiveViewer，避免 pinch 焦点漂移。
  void _onScaleChanged(double scale) {
    _currentScale = scale;
    if (_gestureInProgress) return;
    _evalScaleMode();
  }

  /// 根据当前 scale 同步 PageView / Dismiss 启用状态（仅在手势结束时调用）。
  void _evalScaleMode() {
    final atRest = _isAtRest(_currentScale);
    _setGestureMode(enablePageView: atRest, enableDismiss: atRest);
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

  // ─── over-pan detection (zoom 状态) ──────────────────────────────────────
  /// zoom 状态下单指下拖处理。
  ///
  /// 边界判定是显式的：直接读矩阵 translation，只有图片顶边贴住视口顶部
  /// （ty ≥ -ε，说明矩阵已被 clamp、无法再向下平移）且拖动以纵向为主时，
  /// 向下的位移才累计为过拖；累计超过阈值后才转交外部 drag 触发关闭回位。
  /// 未贴边的拖动一律视为平移，绝不触发关闭。
  void _handleSingleFingerMove(PointerMoveEvent event) {
    final last = _lastPointerPosition;
    _lastPointerPosition = event.position;
    if (last == null) return;
    final pointerDeltaY = event.position.dy - last.dy;

    if (_isAtRest(_currentScale)) {
      // rest 状态由 _buildItem 的 VerticalDrag 处理。
      return;
    }

    final translationY = _transformController.value.getTranslation().y;
    final atTopBoundary = translationY >= -_kBoundaryEpsilon;
    final mostlyVertical = pointerDeltaY.abs() > event.delta.dx.abs();

    if (pointerDeltaY > 0 && atTopBoundary && mostlyVertical) {
      _overPanAccumY += pointerDeltaY;
      if (!_externalDragActive && _overPanAccumY >= _kOverPanStartDistance) {
        _externalDragActive = true;
        widget.externalVerticalDragStart?.call(DragStartDetails(
          globalPosition: event.position,
          localPosition: event.localPosition,
        ));
      }
      if (_externalDragActive) {
        widget.externalVerticalDragUpdate?.call(DragUpdateDetails(
          delta: Offset(0, pointerDeltaY),
          primaryDelta: pointerDeltaY,
          globalPosition: event.position,
          localPosition: event.localPosition,
        ));
      }
    } else {
      _overPanAccumY = 0;
      if (_externalDragActive && pointerDeltaY < 0) {
        // 反向拖动 → 取消已开始的外部 drag（图片重新进入可平移区域）。
        _cancelOverPanDrag();
      }
    }
  }

  void _cancelOverPanDrag() {
    _overPanAccumY = 0;
    if (!_externalDragActive) return;
    widget.externalVerticalDragEnd?.call(
      DragEndDetails(velocity: Velocity.zero),
    );
    _externalDragActive = false;
  }

  void _cancelDismissDrag() {
    if (!_externalDismissDragActive) return;
    _externalDismissDragActive = false;
    widget.externalVerticalDragEnd?.call(
      DragEndDetails(velocity: Velocity.zero),
    );
  }

  // ─── boundary callbacks (PageView 协作) ──────────────────────────────────
  void _onLeftBoundaryHit() => _enablePageViewAtZoomBoundary(left: true);
  void _onRightBoundaryHit() => _enablePageViewAtZoomBoundary(left: false);

  /// 已放大状态触及左/右边界：若 PageView 还能往那个方向滑，就打开翻页。
  void _enablePageViewAtZoomBoundary({required bool left}) {
    final pc = _pageController;
    if (pc == null || !pc.hasClients || _enablePageView || widget.isSingle) {
      return;
    }
    final page = pc.page?.round() ?? widget.initIndex;
    final canMove = left ? page > 0 : page < widget.sources.length - 1;
    if (canMove) setState(() => _enablePageView = true);
  }

  void _onNoBoundaryHit() {
    if (_enablePageView) setState(() => _enablePageView = false);
  }

  // ─── page change ─────────────────────────────────────────────────────────
  /// 翻页时立即重置 transform（避免新页继承上一页的缩放/平移状态）。
  void _onPageChanged(int page) {
    setState(() {
      currentIndex = page;
      _enablePageView = true;
      _enableDismiss = true;
    });
    widget.onPageChanged?.call(page);
    if (_transformController.value != Matrix4.identity()) {
      _transformController.value = Matrix4.identity();
      _currentScale = 1.0;
    }
  }

  // ─── close ───────────────────────────────────────────────────────────────
  void _closeWithAnimation() {
    setState(() {
      _dragProgress = 1.0;
      isDismissDrag = true;
      _enablePageView = false;
    });
    if (!mounted) return;
    if (widget.onCloseRequested != null) {
      widget.onCloseRequested!.call();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ─── build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final bgOpacity = (1.0 - _dragProgress).clamp(0.0, 1.0);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          if (widget.showBackground)
            Container(color: Colors.black.withValues(alpha: bgOpacity)),
          // InteractiveViewer：
          // - scaleEnabled 始终为 true，避免 mid-gesture 切换让 ScaleGestureRecognizer
          //   在 2 指落下时才追踪、错过 1 指初始位置（pinch 焦点漂移）。
          // - panEnabled 只看 scale，不看 currentTouchPointNum，保证 pinch 过程 stable。
          // - rest 状态的 1 指下拖由下方 _buildItem 内 GestureDetector 处理。
          InteractiveViewerBoundary(
            controller: _transformController,
            boundaryWidth: MediaQuery.sizeOf(context).width,
            onScaleChanged: _onScaleChanged,
            onLeftBoundaryHit: _onLeftBoundaryHit,
            onRightBoundaryHit: _onRightBoundaryHit,
            onNoBoundaryHit: _onNoBoundaryHit,
            maxScale: widget.maxScale,
            minScale: widget.minScale,
            scaleEnabled: true,
            panEnabled:
                !_hasExternalVerticalDrag || !_isAtRest(_currentScale),
            child: Listener(
              onPointerDown: _onPointerDown,
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerEnd,
              onPointerCancel: _onPointerEnd,
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
                onDragProgress: (p) => setState(() => _dragProgress = p),
                enabled: widget.dismissEnabled && _enableDismiss,
                child: _buildPager(),
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

  Widget _buildPager() {
    if (widget.sources.length == 1 && widget.isSingle) {
      return _buildItem(context, 0, true);
    }
    return PageView.builder(
      onPageChanged: _onPageChanged,
      controller: _pageController,
      physics: _enablePageView ? null : const NeverScrollableScrollPhysics(),
      itemCount: widget.sources.length,
      itemBuilder: (c, i) => _buildItem(c, i, i == currentIndex),
    );
  }

  // ─── pointer routing ─────────────────────────────────────────────────────
  void _onPointerDown(PointerDownEvent event) {
    currentTouchPointNum++;
    if (currentTouchPointNum == 1) {
      _lastPointerPosition = event.position;
      _overPanAccumY = 0;
      return;
    }
    // 第 2 指落下：取消 1 指阶段已吃下的过拖 / dismiss drag，让 pinch 干净接管。
    _cancelOverPanDrag();
    _cancelDismissDrag();
    // 不在这里 setState 关闭 _enablePageView：mid-gesture rebuild 会让
    // ScaleGestureRecognizer 错过 1 指初始位置，pinch 焦点漂移。
    // PageView 在 2 指 pinch 下会自然让位给 ScaleRecognizer。
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (currentTouchPointNum == 1 && _hasExternalVerticalDrag) {
      _handleSingleFingerMove(event);
    }
  }

  void _onPointerEnd(PointerEvent event) {
    currentTouchPointNum =
        (currentTouchPointNum - 1).clamp(0, 10).toInt();
    _cancelOverPanDrag();
    if (currentTouchPointNum == 0) {
      _lastPointerPosition = null;
      _evalScaleMode();
    } else if (currentTouchPointNum <= 1) {
      // pinch 抬起一指回到单指：必须重置基准位置——残留的是另一根手指的
      // 坐标，下一帧会算出虚假的大位移。
      _lastPointerPosition = null;
      if (_isAtRest(_currentScale)) {
        setState(() => _enablePageView = true);
      }
    }
  }

  // ─── item ────────────────────────────────────────────────────────────────
  Widget _buildItem(BuildContext context, int index, bool isFocus) {
    final canDismissDrag =
        _hasExternalVerticalDrag && _isAtRest(_currentScale);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTapDown: (d) => _doubleTapLocalPosition = d.localPosition,
      onDoubleTap: _onDoubleTap,
      onTap: widget.tapToDismiss ? _closeWithAnimation : null,
      // 包装 vertical drag 回调：用 _externalDismissDragActive 标志，
      // 让 2 指落下时能从 _onPointerDown 里取消已经吃下的 dismiss drag。
      onVerticalDragStart: canDismissDrag
          ? (d) {
              if (currentTouchPointNum > 1) return;
              _externalDismissDragActive = true;
              widget.externalVerticalDragStart?.call(d);
            }
          : null,
      onVerticalDragUpdate: canDismissDrag
          ? (d) {
              if (!_externalDismissDragActive) return;
              widget.externalVerticalDragUpdate?.call(d);
            }
          : null,
      onVerticalDragEnd: canDismissDrag
          ? (d) {
              if (!_externalDismissDragActive) return;
              _externalDismissDragActive = false;
              widget.externalVerticalDragEnd?.call(d);
            }
          : null,
      child: widget.itemBuilder(context, index, isFocus),
    );
  }

  // ─── double tap zoom ─────────────────────────────────────────────────────
  /// 双击在 minScale 与 0.7×maxScale 之间切换，并以点击位置为锚点平移。
  void _onDoubleTap() {
    final currentScale = _transformController.value.row0.x;
    final atMin = currentScale <= widget.minScale;
    final targetScale = atMin ? widget.maxScale * 0.7 : widget.minScale;

    final dx = targetScale == 1.0
        ? 0.0
        : -_doubleTapLocalPosition.dx * (targetScale - 1);
    final dy = targetScale == 1.0
        ? 0.0
        : -_doubleTapLocalPosition.dy * (targetScale - 1);

    final target = Matrix4.identity()
      ..scaleByDouble(targetScale, targetScale, targetScale, 1)
      ..setEntry(0, 3, dx)
      ..setEntry(1, 3, dy);

    _doubleTapAnimation = Matrix4Tween(
      begin: _transformController.value,
      end: target,
    ).animate(CurveTween(curve: Curves.easeOut).animate(_doubleTapAnim));
    _doubleTapAnim
        .forward(from: 0)
        .whenComplete(() => _onScaleChanged(targetScale));
  }

  // ─── decorations ─────────────────────────────────────────────────────────
  Widget _buildIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(widget.sources.length, (i) {
        final active = i == currentIndex;
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
      automaticallyImplyLeading: false,
      title: widget.isSingle
          ? null
          : Text(
              '${currentIndex! + 1} / ${widget.sources.length}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
              ),
            ),
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
}
