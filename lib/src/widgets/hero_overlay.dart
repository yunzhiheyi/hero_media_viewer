import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ============================================================================
// Public types
// ============================================================================

/// 控制 hero overlay 的开/关，以及监听源 widget 是否处于"飞行"状态。
///
/// 由 [showHeroOverlay] / [showHeroPageOverlay] 内部创建并赋值；外部也可
/// 自行构造后传入，用于在合适的时机（例如父页面 dispose）主动 [close] / [dismiss]。
///
/// [close] 走"动画关闭"路径，[dismiss] 直接拆掉 OverlayEntry，无动画。
class HeroOverlayController {
  OverlayEntry? _overlayEntry;
  VoidCallback? _animatedClose;
  VoidCallback? _onDismiss;
  bool _isShowing = false;

  /// `true` 时说明 overlay 正处于飞行 / 已展开状态。
  final ValueNotifier<bool> _sourceHidden = ValueNotifier<bool>(false);

  /// overlay 当前是否处于已 show 状态。
  bool get isShowing => _isShowing;

  /// 源 widget 是否应当被隐藏（用 `Visibility(maintainSize:true,...)` 包裹源 widget
  /// 即可在 overlay 飞行期间让原位置"看上去空着"，与 Flutter 自带 Hero 行为一致）。
  ValueListenable<bool> get sourceHidden => _sourceHidden;

  /// 走自定义关闭动画；若没有可用的动画回调则降级为 [dismiss]。
  void close() {
    if (!_isShowing) return;
    final animated = _animatedClose;
    if (animated != null) {
      animated();
    } else {
      dismiss();
    }
  }

  /// 直接拆 overlay（不走动画）。
  void dismiss() {
    if (!_isShowing) return;
    final onDismiss = _onDismiss;
    if (onDismiss != null) {
      onDismiss();
      return;
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
    _animatedClose = null;
    _isShowing = false;
    _sourceHidden.value = false;
  }
}

/// 拖动关闭事件三元组回调签名（start / update / end 一次性提供）。
typedef DragCloseCallback =
    void Function(
      DragStartDetails start,
      DragUpdateDetails update,
      DragEndDetails end,
      bool isBackground,
    );

/// 由 overlay 透传给内容 widget 的三个 drag 回调。
///
/// 内容 widget 自己有手势检测时（如 [InteractiveGalleryViewer]），把这三个
/// 回调挂到自己的 vertical drag 上即可让 overlay 跟随手指做关闭回位动画。
class HeroOverlayDragHandlers {
  const HeroOverlayDragHandlers({
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
  });

  final GestureDragStartCallback onStart;
  final GestureDragUpdateCallback onUpdate;
  final GestureDragEndCallback onEnd;
}

/// 多图画廊底部页码指示点。
///
/// 内置在多图 overlay 的 [HeroOverlayForegroundBuilder] 中；调用方也可在
/// 自定义 foreground 中直接使用。
class HeroOverlayPageIndicator extends StatelessWidget {
  const HeroOverlayPageIndicator({
    super.key,
    required this.count,
    required this.index,
    this.bottomSpacing = 18,
  });

  final int count;
  final int index;

  /// 距离屏幕底部 safe area 之上的额外间距。
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: MediaQuery.of(context).padding.bottom + bottomSpacing,
      child: IgnorePointer(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(count, (i) {
            final active = i == index;
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

/// 关闭回位动画时叠在 overlay 之上的"缩略图预览"构建器。
typedef HeroOverlayCloseBuilder =
    Widget Function(BuildContext context, int index, double progress);

/// 打开动画时叠在 overlay 之上的"缩略图预览"构建器。
typedef HeroOverlayOpenBuilder =
    Widget Function(BuildContext context, int index, double progress);

/// 长驻在 overlay 之上的浮层（页码指示器、保存按钮、字幕等）。
typedef HeroOverlayForegroundBuilder =
    Widget Function(BuildContext context, int index);

/// 根据当前 index 返回目标矩形（如关闭时飞回到哪个 thumbnail）。
typedef HeroOverlayTargetRectBuilder = Rect Function(int index);

/// 页面 hero overlay 的内容构建器签名。
typedef HeroOverlayPageBuilder =
    Widget Function(
      BuildContext context,
      HeroOverlayController controller,
      HeroOverlayDragHandlers dragHandlers,
    );

// ============================================================================
// Public APIs
// ============================================================================

/// 打开一个 hero overlay。
///
/// 这是所有 hero overlay API 的底层入口。展开流程：从 [startRect] 计算出
/// [targetRect]（默认按 [aspectRatio] 居中或 [fullScreen] 全屏）→ 动画过渡
/// → 用户 tap/drag 后关闭 → 飞回到当前 index 对应的矩形。
///
/// 关键参数：
/// - [startRect]：起始矩形（缩略图全局位置），用 [getWidgetGlobalRect] 获取。
/// - [itemRects]：每个 index 对应的源矩形，多图 overlay 切页后用对应矩形作为关闭目标。
/// - [showBackdrop]：是否始终显示黑色背景；图片/视频 overlay 默认 true，页面 overlay 默认 false。
/// - [dragBackdropOpacity]：拖动过程中背景渐显的强度（仅 [showBackdrop] 为 false 时生效）。
/// - [dimBackdropOnDrag]：下拖关闭时是否让黑色遮罩随拖动距离淡出；媒体预览
///   默认开启，呈现微信式“媒体平移、背景渐隐”的反馈。
///
/// 内部会同步向 Navigator 推一个隐藏的哨兵 Route（[_HeroSentinelRoute]），
/// 用于拦截 Android 物理返回键、Android 14 预测返回手势、iOS 边缘侧滑。
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
  Map<int, double>? itemAspectRatios,
  bool tapToClose = true,
  bool dragToClose = true,
  bool showCloseButton = true,
  bool showBackdrop = true,
  double dragBackdropOpacity = 0.0,
  bool dimBackdropOnDrag = true,
}) {
  final overlayController = controller ?? HeroOverlayController();
  final navigator = Navigator.maybeOf(context);
  final overlayState = Overlay.of(context);

  late OverlayEntry overlayEntry;
  _HeroSentinelRoute? sentinelRoute;
  bool cleaningUp = false;

  // 幂等清理：动画自然结束、controller.dismiss()、外部 popUntil 都走这里。
  void cleanup() {
    if (cleaningUp) return;
    cleaningUp = true;

    if (overlayEntry.mounted) overlayEntry.remove();
    overlayController
      .._overlayEntry = null
      .._animatedClose = null
      .._onDismiss = null
      .._isShowing = false
      .._sourceHidden.value = false;

    final route = sentinelRoute;
    if (route != null && route.isActive && navigator != null) {
      navigator.removeRoute(route);
    }
    onClose?.call();
  }

  overlayEntry = OverlayEntry(
    builder:
        (_) => _HeroOverlayView(
          startRect: startRect,
          aspectRatio: aspectRatio,
          fullScreen: fullScreen,
          itemRects: itemRects,
          initialIndex: initialIndex,
          currentIndexListenable: currentIndexListenable,
          onIndexChanged: onIndexChanged,
          itemAspectRatios: itemAspectRatios,
          tapToClose: tapToClose,
          dragToClose: dragToClose,
          showCloseButton: showCloseButton,
          showBackdrop: showBackdrop,
          dragBackdropOpacity: dragBackdropOpacity,
          dimBackdropOnDrag: dimBackdropOnDrag,
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

  overlayController
    .._overlayEntry = overlayEntry
    .._isShowing = true
    .._onDismiss = cleanup
    .._sourceHidden.value = true;

  // 顺序很关键：先 push 哨兵 Route（吸收下层路由的边缘手势 + 拦物理返回），
  // 再 insert OverlayEntry。z-order 上 overlay 在哨兵之上，hero 自己的手势不受影响；
  // 漏掉的事件被哨兵吸收，到不了底层路由。
  if (navigator != null) {
    sentinelRoute = _HeroSentinelRoute(
      onPopRequest: overlayController.close,
      onRemoved: cleanup,
    );
    navigator.push(sentinelRoute);
  }
  overlayState.insert(overlayEntry);
}

/// 打开一个"页面级"的 hero overlay。
///
/// 与 [showHeroOverlay] 的区别：默认不显示黑色背景（[showBackdrop] false）、
/// 使用 shared-element 过渡（详情卡片在打开/关闭动画过程中保持目标尺寸不动）、
/// [maintainChildSize] true 保证内容布局稳定。适合"卡片展开成全屏页面"这种场景。
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
  bool dimBackdropOnDrag = true,
  Duration openDuration = const Duration(milliseconds: 360),
  Duration closeDuration = const Duration(milliseconds: 300),
  Duration resetDuration = const Duration(milliseconds: 260),
}) {
  final overlayController = controller ?? HeroOverlayController();
  final screenTarget = targetRect ?? (Offset.zero & MediaQuery.sizeOf(context));

  showHeroOverlay(
    context: context,
    startRect: startRect,
    targetRect: screenTarget,
    maintainChildSize: true,
    fullScreen: false,
    controller: overlayController,
    onClose: onClose,
    tapToClose: tapToClose,
    dragToClose: dragToClose,
    showBackdrop: showBackdrop,
    dragBackdropOpacity: dragBackdropOpacity,
    dimBackdropOnDrag: dimBackdropOnDrag,
    openDuration: openDuration,
    closeDuration: closeDuration,
    resetDuration: resetDuration,
    openBuilder: openBuilder,
    closeBuilder: closeBuilder,
    closeRectBuilder: closeRectBuilder,
    sharedElementTargetRectBuilder: sharedElementTargetRectBuilder,
    dragBuilder:
        (ctx, dragHandlers) => builder(ctx, overlayController, dragHandlers),
  );
}

/// 通过 [GlobalKey] 测量挂载的 widget 在屏幕上的全局矩形。
///
/// widget 未挂载或已 unmounted 时返回 [Rect.zero]。配合 [showHeroOverlay.startRect]
/// 使用，用于在缩略图被点击时获取真实位置。
Rect getWidgetGlobalRect(GlobalKey key) {
  final renderObject = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderObject == null) return Rect.zero;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
}

// ============================================================================
// _HeroOverlayView
// ============================================================================

class _HeroOverlayView extends StatefulWidget {
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
    this.itemAspectRatios,
    this.tapToClose = true,
    this.dragToClose = true,
    this.showCloseButton = true,
    this.showBackdrop = true,
    this.dragBackdropOpacity = 0.0,
    this.dimBackdropOnDrag = true,
  });

  final Rect startRect;
  final Rect? targetRect;
  final bool maintainChildSize;
  final Duration openDuration;
  final Duration closeDuration;
  final Duration resetDuration;
  final double? aspectRatio;
  final bool fullScreen;
  final HeroOverlayController controller;
  final Widget Function(BuildContext, DragCloseCallback?)? builder;
  final Widget Function(BuildContext, HeroOverlayDragHandlers)? dragBuilder;
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
  final Map<int, double>? itemAspectRatios;
  final bool tapToClose;
  final bool dragToClose;
  final bool showCloseButton;
  final bool showBackdrop;
  final double dragBackdropOpacity;
  final bool dimBackdropOnDrag;

  @override
  State<_HeroOverlayView> createState() => _HeroOverlayViewState();
}

class _HeroOverlayViewState extends State<_HeroOverlayView>
    with TickerProviderStateMixin {
  // ─── animation controllers ───────────────────────────────────────────────
  AnimationController? _expandController; // 0=startRect 状态, 1=targetRect 状态
  AnimationController? _dragController; // 关闭 / 回位动画

  // ─── flags ───────────────────────────────────────────────────────────────
  bool _isClosing = false;
  bool _isResetting = false;
  bool _initialized = false;

  // ─── geometry ────────────────────────────────────────────────────────────
  late Rect _startRect;
  late Rect _targetRect;
  late Size _screenSize;
  late double _aspectRatio;
  late int _currentIndex;

  // ─── drag state ──────────────────────────────────────────────────────────
  /// 当前累计的拖动位移。
  double _dragOffsetX = 0.0;
  double _dragOffsetY = 0.0;

  /// 关闭起始 opacity / 关闭进度 0~1。
  double _startOpacity = 1.0;
  double _closeAnimValue = 0.0;

  /// reset（回位）期间记录的起始 opacity 等，用于动画过渡。
  double _resetStartOpacity = 1.0;
  double _resetStartForegroundOpacity = 1.0;
  double _resetAnimValue = 0.0;

  /// 关闭 / 回位动画的起点矩形快照。
  Rect? _closeStartRect;
  Rect? _resetStartRect;

  /// 上一次 drag 的全局位置，用于校正 delta（避免 PageView 等下层 widget 吃掉部分位移）。
  Offset? _lastDragGlobalPosition;

  // ─── lifecycle ───────────────────────────────────────────────────────────
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
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

  /// 计算展开后矩形：优先用调用方传入的 [widget.targetRect]，否则按 fullScreen
  /// 取屏幕全屏；非 fullScreen 时按 aspectRatio 居中放大并 fit 进屏幕。
  void _calculateTargetRect(double aspectRatio) {
    _aspectRatio = aspectRatio;

    if (widget.targetRect != null) {
      _targetRect = widget.targetRect!;
      return;
    }
    if (widget.fullScreen) {
      _targetRect = Offset.zero & _screenSize;
      return;
    }
    var w = _screenSize.width;
    var h = w / aspectRatio;
    if (h > _screenSize.height) {
      h = _screenSize.height;
      w = h * aspectRatio;
    }
    _targetRect = Rect.fromCenter(
      center: _screenSize.center(Offset.zero),
      width: w,
      height: h,
    );
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

  void _handleCurrentIndexChanged() {
    updateCurrentIndex(widget.currentIndexListenable!.value);
  }

  /// 外部通知 index 变化（如 PageView 翻页）：更新当前索引 + 同步起点矩形。
  ///
  /// 若 [widget.itemAspectRatios] 提供了目标索引的宽高比且 overlay 不是
  /// fullScreen 模式，同步重算 [_targetRect] 使容器适配新图片尺寸。
  void updateCurrentIndex(int index) {
    if (_currentIndex == index) return;
    setState(() {
      _currentIndex = index;
      final rect = widget.itemRects?[index];
      if (rect != null) _startRect = rect;

      final newAspect = widget.itemAspectRatios?[index];
      if (newAspect != null &&
          !widget.fullScreen &&
          widget.targetRect == null) {
        _calculateTargetRect(newAspect);
      }
    });
    widget.onIndexChanged?.call(index);
  }

  // ─── drag handlers ───────────────────────────────────────────────────────
  /// drag 开始：记录初始全局位置；媒体只平移，不跟随手势缩放。
  ///
  /// [isBackground] 表示拖动是在背景层发起的（非内容层）；目前仅记录，无差异化处理。
  void _handleDragStart(DragStartDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;
    widget.onDragStateChanged?.call(true);
    _lastDragGlobalPosition = details.globalPosition;
  }

  /// drag 更新：用 globalPosition 差分代替 details.delta，避免下层 widget 吃掉部分位移。
  void _handleDragUpdate(DragUpdateDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;

    var delta = details.delta;
    final last = _lastDragGlobalPosition;
    if (last != null) {
      final globalDelta = details.globalPosition - last;
      if (globalDelta.distanceSquared > 0) delta = globalDelta;
    }
    _lastDragGlobalPosition = details.globalPosition;

    _dragOffsetX += delta.dx;
    _dragOffsetY += delta.dy;
    setState(() {});
  }

  /// drag 结束：dragOffsetY > 100 或速度 > 500 走关闭，否则回位。
  void _handleDragEnd(DragEndDetails details, bool isBackground) {
    if (_isClosing || _isResetting) return;
    widget.onDragStateChanged?.call(false);
    _lastDragGlobalPosition = null;

    final v = details.velocity.pixelsPerSecond.dy;
    if (_dragOffsetY > 100.0 || v > 500) {
      _closeWithDrag();
    } else {
      _resetDrag();
    }
  }

  /// 把三个 drag 事件打包成单个回调（兼容 [builder] 形参）。
  DragCloseCallback _createDragCloseCallback() {
    return (start, update, end, isBackground) {
      _handleDragStart(start, isBackground);
      _handleDragUpdate(update, isBackground);
      _handleDragEnd(end, isBackground);
    };
  }

  HeroOverlayDragHandlers _createDragHandlers() => HeroOverlayDragHandlers(
    onStart: (d) => _handleDragStart(d, false),
    onUpdate: (d) => _handleDragUpdate(d, false),
    onEnd: (d) => _handleDragEnd(d, false),
  );

  // ─── rect helpers ────────────────────────────────────────────────────────
  Rect _getCurrentRect() {
    final t = _expandController?.value ?? 0.0;
    return Rect.lerp(_startRect, _targetRect, t)!;
  }

  /// 当前显示矩形（只应用拖动位移，媒体尺寸保持不变）。
  Rect _getDraggedRect() {
    final base = _getCurrentRect();
    return base.shift(Offset(_dragOffsetX, _dragOffsetY));
  }

  /// 关闭目标矩形：优先 closeRectBuilder → itemRects[index] → 原 startRect →
  /// 退化为"原地坍缩"（避免飞向屏幕左上角 (0,0)）。
  Rect _getCloseTargetRect() {
    final built = widget.closeRectBuilder?.call(_currentIndex);
    if (_isValidRect(built)) return built!;

    final mapped = widget.itemRects?[_currentIndex];
    if (_isValidRect(mapped)) return mapped!;

    if (_isValidRect(_startRect)) return _startRect;

    // 源 widget 已经被滚走 / dispose / 从未测量到。
    return _closeStartRect ?? _targetRect;
  }

  bool _isValidRect(Rect? r) =>
      r != null &&
      !r.isEmpty &&
      r.right > 0 &&
      r.bottom > 0 &&
      r.left < _screenSize.width &&
      r.top < _screenSize.height;

  // ─── close paths ─────────────────────────────────────────────────────────
  /// 拖动触发的关闭：以当前拖动后矩形为起点，匀速过渡到目标矩形。
  void _closeWithDrag() {
    if (_isClosing) return;
    _isClosing = true;

    _closeStartRect = _getDraggedRect();
    _startOpacity = 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: widget.closeDuration,
      vsync: this,
    );
    final curve = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    curve.addListener(() => setState(() => _closeAnimValue = curve.value));
    curve.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onClose();
    });
    _dragController!.forward();
  }

  /// 拖动未达阈值的回位动画：以当前拖动后矩形为起点，回到 _targetRect。
  void _resetDrag() {
    if (_isResetting) return;
    _isResetting = true;
    _resetStartRect = _getDraggedRect();
    _resetAnimValue = 0.0;
    _resetStartOpacity =
        1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    _resetStartForegroundOpacity = _foregroundOpacityFromDragOffset();

    _dragController?.dispose();
    _dragController = AnimationController(
      duration: widget.resetDuration,
      vsync: this,
    );
    final anim = CurvedAnimation(
      parent: _dragController!,
      curve: Curves.fastOutSlowIn,
    );

    anim.addListener(() => setState(() => _resetAnimValue = anim.value));
    anim.addStatusListener((status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      setState(() {
        _isResetting = false;
        _resetStartRect = null;
        _resetAnimValue = 0.0;
        _resetStartOpacity = 1.0;
        _resetStartForegroundOpacity = 1.0;
        _dragOffsetX = 0;
        _dragOffsetY = 0;
        _lastDragGlobalPosition = null;
      });
    });
    _dragController!.forward();
  }

  /// 按钮关闭 / 程序化关闭：从当前矩形回位到 close 目标矩形。
  /// 若两者宽高比差异较大，会先把起始矩形按目标比例校正一次，避免动画过程拉伸。
  void _close() {
    if (_isClosing) return;
    _isClosing = true;

    final closeTarget = _getCloseTargetRect();
    final targetAspect = closeTarget.width / closeTarget.height;
    final current = _getCurrentRect();
    final currentAspect = current.width / current.height;

    if ((targetAspect - currentAspect).abs() > 0.01) {
      final h = current.width / targetAspect;
      final y = current.center.dy - h / 2;
      _closeStartRect = Rect.fromLTWH(current.left, y, current.width, h);
    } else {
      _closeStartRect = current;
    }

    _startOpacity = 1.0;
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
    curve.addListener(() => setState(() => _closeAnimValue = curve.value));
    curve.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onClose();
    });
    _dragController!.forward();
  }

  // ─── build ───────────────────────────────────────────────────────────────
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
            _buildBackdrop(),
          _buildContent(),
          if (widget.showCloseButton) _buildCloseButton(),
          if (!_isClosing && widget.foregroundBuilder != null)
            _buildForeground(),
        ],
      ),
    );
  }

  Widget _buildBackdrop() {
    return GestureDetector(
      onTap:
          widget.tapToClose && !_isClosing && _dragOffsetY < 10 ? _close : null,
      onPanStart: widget.dragToClose ? (d) => _handleDragStart(d, true) : null,
      onPanUpdate:
          widget.dragToClose ? (d) => _handleDragUpdate(d, true) : null,
      onPanEnd: widget.dragToClose ? (d) => _handleDragEnd(d, true) : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_expandController, _dragController]),
        builder: (_, __) {
          final opacity =
              widget.showBackdrop
                  ? _fullBackdropOpacity()
                  : _dragOnlyBackdropOpacity();
          return Container(
            key: const ValueKey('hero-overlay-backdrop'),
            color: Colors.black.withValues(alpha: opacity),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedBuilder(
      animation: Listenable.merge([_expandController, _dragController]),
      builder: (_, child) {
        final rect = _computeContentRect();
        return _buildAnimatedOverlayChild(context, rect, child!);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.zero,
        child:
            widget.dragBuilder?.call(context, _createDragHandlers()) ??
            widget.builder?.call(context, _createDragCloseCallback()) ??
            const SizedBox.shrink(),
      ),
    );
  }

  /// 根据当前动画阶段（resetting / closing / opening）决定 overlay 显示矩形。
  Rect _computeContentRect() {
    if (_isResetting && _resetStartRect != null) {
      return Rect.lerp(_resetStartRect!, _targetRect, _resetAnimValue)!;
    }
    if (_isClosing && _closeStartRect != null) {
      final closeTarget = _getCloseTargetRect();
      final targetAspect = closeTarget.width / closeTarget.height;
      final currentAspect = _closeStartRect!.width / _closeStartRect!.height;

      var start = _closeStartRect!;
      // 宽高比差异较大时，把起点按目标比例校正，避免动画过程明显拉伸。
      if ((targetAspect - currentAspect).abs() > 0.1) {
        final h = start.width / targetAspect;
        final y = start.center.dy - h / 2;
        start = Rect.fromLTWH(start.left, y, start.width, h);
      }
      return Rect.lerp(start, closeTarget, _closeAnimValue)!;
    }
    // opening / 拖动跟随。
    final t = _expandController!.value;
    final base = Rect.lerp(_startRect, _targetRect, t)!;
    return base.shift(Offset(_dragOffsetX, _dragOffsetY));
  }

  Widget _buildCloseButton() {
    return AnimatedBuilder(
      animation: Listenable.merge([_expandController, _dragController]),
      builder: (_, __) {
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
                child: const Icon(Icons.close, color: Colors.white, size: 24),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildForeground() {
    return AnimatedBuilder(
      animation: Listenable.merge([_expandController, _dragController]),
      builder:
          (_, __) => Positioned.fill(
            child: Opacity(
              opacity: _foregroundOpacity(),
              child: Stack(
                children: [widget.foregroundBuilder!(context, _currentIndex)],
              ),
            ),
          ),
    );
  }

  // ─── opacity helpers ─────────────────────────────────────────────────────
  /// 背景全程透明度（[widget.showBackdrop] 为 true 时使用）。
  double _fullBackdropOpacity() {
    final t = _expandController!.value;
    if (_isClosing && _closeStartRect != null) {
      return _startOpacity * (1.0 - _closeAnimValue);
    }
    if (_isResetting) {
      return _resetStartOpacity + (1.0 - _resetStartOpacity) * _resetAnimValue;
    }
    if (_isClosing || t < 1.0) return t;
    if (_dragOffsetY > 0 && widget.dimBackdropOnDrag) {
      return 1.0 - (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    }
    return 1.0;
  }

  /// 仅拖动期间显示的背景透明度（页面 hero overlay 用）。
  double _dragOnlyBackdropOpacity() {
    final max = widget.dragBackdropOpacity.clamp(0.0, 1.0);
    if (max <= 0) return 0.0;

    final progress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
    final base = progress * max;

    if (_isClosing && _closeStartRect != null) {
      return base * (1.0 - _closeAnimValue);
    }
    if (_isResetting) return base * (1.0 - _resetAnimValue);
    return base;
  }

  /// 浮层（foreground）整体透明度：随展开进度淡入、随拖动淡出。
  double _foregroundOpacity() {
    final expand = ((_expandController?.value ?? 0.0) * 2).clamp(0.0, 1.0);
    if (_isResetting) {
      return (_resetStartForegroundOpacity +
              (1.0 - _resetStartForegroundOpacity) * _resetAnimValue)
          .clamp(0.0, 1.0);
    }
    return (expand * _foregroundOpacityFromDragOffset()).clamp(0.0, 1.0);
  }

  /// 拖动距离对应的浮层透明度（120 px 内线性淡出到 0）。
  double _foregroundOpacityFromDragOffset() {
    const fadeDistance = 120.0;
    if (_dragOffsetY <= 0) return 1.0;
    return (1.0 - (_dragOffsetY / fadeDistance).clamp(0.0, 1.0)).clamp(
      0.0,
      1.0,
    );
  }

  // ─── content wrappers ────────────────────────────────────────────────────
  /// 把 [child] 包装到 overlay 的矩形里，并挂上 tap / vertical drag 关闭手势。
  ///
  /// 三种渲染模式：
  /// 1. 默认（!maintainChildSize）：[Positioned] 按 rect 摆放，最简单。
  /// 2. sharedElement：详情卡片始终在 targetRect 位置，flying preview 用 openBuilder/
  ///    closeBuilder 在另一层渲染，做到"卡片本身不动，外形渐变"。
  /// 3. maintainChildSize：[Transform.scale] + [Transform.translate] 模拟矩形变化，
  ///    内部布局按 targetRect 测量，避免 reflow。
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
    if (usesSharedElement) {
      return _buildSharedElementPageTransition(rect, overlayChild);
    }

    final detailOpacity = _maintainedDetailOpacity();
    final preview = _buildMaintainedTransitionPreview(rect);
    return Stack(
      children: [
        if (preview != null) preview,
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

  /// shared-element 模式的渲染：详情层（按 targetRect 摆放、透明度变化）+ 飞行预览层。
  Widget _buildSharedElementPageTransition(Rect rect, Widget child) {
    final detailOpacity = _sharedElementDetailOpacity();
    final preview = _buildSharedElementTransitionPreview(rect);
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
        if (preview != null) preview,
      ],
    );
  }

  /// 以 targetRect 为基准，用 translate + scale 模拟"rect 大小的视觉效果"。
  /// 内部布局按 targetRect 测量，所以维持子元素的布局稳定。
  Widget _buildMaintainedTransform(Rect rect, Widget child) {
    final sx = _targetRect.width == 0 ? 1.0 : rect.width / _targetRect.width;
    final sy = _targetRect.height == 0 ? 1.0 : rect.height / _targetRect.height;
    return Transform.translate(
      offset: Offset(rect.left - _targetRect.left, rect.top - _targetRect.top),
      child: Transform.scale(
        alignment: Alignment.topLeft,
        scaleX: sx,
        scaleY: sy,
        child: SizedBox(
          width: _targetRect.width,
          height: _targetRect.height,
          child: child,
        ),
      ),
    );
  }

  /// 普通 maintain 模式下的过渡预览（如缩略图淡入/淡出）。
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

    if (opacity <= 0) return null;
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

  /// shared-element 模式下的过渡预览（飞行中的卡片/缩略图）。
  Widget? _buildSharedElementTransitionPreview(Rect rect) {
    final opening =
        !_isClosing && !_isResetting && _expandController!.value < 1;
    final closing = _isClosing && _closeStartRect != null;
    final target = _getSharedElementTargetRect();

    final Widget? preview;
    final Rect previewRect;
    final double opacity;

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

    if (opacity <= 0) return null;
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
    final r = widget.sharedElementTargetRectBuilder?.call(_currentIndex);
    return (r != null && !r.isEmpty) ? r : _targetRect;
  }

  double _sharedElementDetailOpacity() {
    if (_isClosing && _closeStartRect != null && widget.closeBuilder != null) {
      return (1.0 - _interval(_closeAnimValue, 0.04, 0.30)).clamp(0.0, 1.0);
    }
    if (_dragOffsetY > 0 && !_isClosing && !_isResetting) {
      final progress = (_dragOffsetY / _screenSize.height).clamp(0.0, 1.0);
      return (1.0 - progress * 0.35).clamp(0.0, 1.0);
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

  /// 缓动函数：value 在 [start, end] 之间走 easeOutCubic，0 或 1 之外做 clamp。
  double _interval(double value, double start, double end) {
    if (value <= start) return 0.0;
    if (value >= end) return 1.0;
    return Curves.easeOutCubic.transform((value - start) / (end - start));
  }

  /// 打开 / 关闭过程中用 openBuilder / closeBuilder 在内容之上做平滑过渡。
  ///
  /// 设计前提：调用方传入的 openBuilder / closeBuilder 自己已经按 progress 平滑
  /// 插值（如 [AnimatedFitImage] 做 cover ↔ contain 渐变），且在 progress 边界处
  /// 渲染结果与 child 一致——这样 t=1 / outer=0 切换都不会肉眼可见。
  Widget _buildOverlayContent(BuildContext context, Widget child) {
    // 关闭：closeBuilder 完全盖在 child 之上。
    // outer=0：closeBuilder 渲染 contain，与 child 一致，切入无感；
    // outer=1：closeBuilder 渲染缩略图 fit，匹配 startRect。
    if (_isClosing && _closeStartRect != null && widget.closeBuilder != null) {
      final progress = _closeAnimValue.clamp(0.0, 1.0);
      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          IgnorePointer(
            child: widget.closeBuilder!(context, _currentIndex, progress),
          ),
        ],
      );
    }

    // 打开：t < 1 时 openBuilder 不透明地盖在 child 上自己负责过渡；
    // t = 1 时移除 openBuilder，由 child 接管（此时两者渲染一致，切换不可见）。
    if (!_isClosing &&
        !_isResetting &&
        widget.openBuilder != null &&
        _expandController != null) {
      final t = _expandController!.value.clamp(0.0, 1.0);
      if (t < 1.0) {
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            IgnorePointer(
              child: widget.openBuilder!(context, _currentIndex, t),
            ),
          ],
        );
      }
    }

    return child;
  }
}

/// 外部访问 [_HeroOverlayViewState.updateCurrentIndex] 的抽象（保留作为扩展点）。
abstract class HeroOverlayViewState {
  void updateCurrentIndex(int index);
}

// ============================================================================
// Sentinel route
// ============================================================================

/// 哨兵 Route：与 hero overlay 配对推入 Navigator。
///
/// 职责：
/// 1. [PopScope] canPop:false 拦截 Android 物理返回键 + Android 14 预测返回手势，
///    转走自定义关闭动画。
/// 2. 全屏 [AbsorbPointer] 吸收下层路由的边缘手势（iOS 左滑返回），让
///    CupertinoPageRoute 的 _CupertinoBackGestureDetector 拿不到 touch。
/// 3. [dispose] 时回调 onRemoved，保证外部 popUntil/removeRoute 等场景下 overlay
///    entry 也能被清掉。
class _HeroSentinelRoute<T> extends PageRouteBuilder<T> {
  _HeroSentinelRoute({required this.onPopRequest, required this.onRemoved})
    : super(
        opaque: false,
        barrierDismissible: false,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        maintainState: true,
        pageBuilder: (_, _, _) => const SizedBox.shrink(),
      );

  final VoidCallback onPopRequest;
  final VoidCallback onRemoved;
  bool _onRemovedFired = false;

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
      child: const AbsorbPointer(child: SizedBox.expand()),
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
