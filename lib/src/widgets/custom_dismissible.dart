import 'package:flutter/material.dart';

/// 下滑关闭手势容器。
///
/// 包裹任意 [child]，监听竖向 drag：手指下拖时同步缩小、淡出、向下平移；
/// 松手后根据当前进度决定 [onDismissed] 或回弹到原位（动画时长 300ms）。
///
/// 与 Flutter 自带 [Dismissible] 的区别：
/// - 关闭方向固定为向下，且向上拖动不会累积进度。
/// - 暴露 [stopDrag] 让父组件在多指 pinch 等场景临时切断手势。
/// - 提供 [onDragProgress] 让背景透明度等装饰可以跟着拖动同步变化。
class CustomDismissible extends StatefulWidget {
  const CustomDismissible({
    super.key,
    required this.child,
    this.onDismissed,
    this.onDismissDragStart,
    this.onDismissDragCancel,
    this.onDragProgress,
    this.dismissThreshold = 0.2,
    this.enabled = true,
    this.stopDrag = false,
  });

  /// 被包裹的内容。
  final Widget child;

  /// 触发关闭的进度阈值（0~1），松手时 _animateController.value 超过它才回调 [onDismissed]。
  final double dismissThreshold;

  /// 关闭动画完成（达到阈值）后回调。
  final VoidCallback? onDismissed;

  /// 拖动开始（手势被识别）时回调。
  final VoidCallback? onDismissDragStart;

  /// 拖动取消（未达阈值，回弹）时回调。
  final VoidCallback? onDismissDragCancel;

  /// 拖动进度变化时回调（0~1）。
  final void Function(double progress)? onDragProgress;

  /// 总开关；为 false 时不响应任何手势。
  final bool enabled;

  /// 临时切断当前拖动：true 时丢弃后续手势事件，并在切回 false 后回弹。
  final bool stopDrag;

  @override
  State<CustomDismissible> createState() => _CustomDismissibleState();
}

class _CustomDismissibleState extends State<CustomDismissible>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animateController = AnimationController(
    duration: const Duration(milliseconds: 300),
    vsync: this,
  );
  late Animation<Offset> _moveAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  bool _dragUnderway = false;
  Offset _dragOffset = Offset.zero;

  bool get _isActive => _dragUnderway || _animateController.isAnimating;

  @override
  void initState() {
    super.initState();
    _updateMoveAnimation();
  }

  @override
  void dispose() {
    _animateController.dispose();
    super.dispose();
  }

  /// 根据当前 [_dragOffset] 计算飞出方向，更新 slide / scale / opacity 三组 Tween。
  ///
  /// 仅向下拖动累积进度（endY=1）；横向偏移按比例小幅倾斜并 clamp 在 ±0.8。
  void _updateMoveAnimation() {
    final endY = _dragOffset.dy <= 0 ? 0.0 : 1.0;
    final endX = (_dragOffset.dx / (_dragOffset.dy.abs() + 0.01))
        .clamp(-0.8, 0.8);

    _moveAnimation = _animateController.drive(
      Tween(begin: Offset.zero, end: Offset(endX, endY)),
    );
    _scaleAnimation = _animateController.drive(Tween(begin: 1.0, end: 0.0));
    _opacityAnimation = _animateController.drive(Tween(begin: 1.0, end: 0.0));
  }

  void _handleDragStart(DragStartDetails _) {
    _dragUnderway = true;
    widget.onDismissDragStart?.call();
    if (_animateController.isAnimating) {
      _animateController.stop();
    } else {
      _dragOffset = Offset.zero;
      _animateController.value = 0.0;
    }
    setState(_updateMoveAnimation);
  }

  void _handleDragEnd(DragEndDetails _) {
    if (!_isActive || _animateController.isAnimating) return;
    resetDrag();
  }

  /// 结束当前拖动：进度过阈值则 [onDismissed]，否则回弹并回调 cancel。
  void resetDrag() {
    _dragUnderway = false;
    if (_animateController.isCompleted || _animateController.isDismissed) {
      return;
    }
    if (_animateController.value > widget.dismissThreshold) {
      widget.onDismissed?.call();
    } else {
      widget.onDragProgress?.call(0);
      widget.onDismissDragCancel?.call();
      _animateController.reverse();
    }
  }

  @override
  void didUpdateWidget(covariant CustomDismissible oldWidget) {
    super.didUpdateWidget(oldWidget);
    // stopDrag 从 true 切回 false 时主动重置：避免 pinch 结束后留下停在半路的 drag。
    if (oldWidget.stopDrag && !widget.stopDrag) {
      WidgetsBinding.instance.addPostFrameCallback((_) => resetDrag());
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_dragUnderway || _animateController.isAnimating) return;
    _dragOffset += event.delta;
    setState(_updateMoveAnimation);

    final progress =
        _dragOffset.dy <= 0 ? 0.0 : _dragOffset.dy / context.size!.height;
    _animateController.value = progress.clamp(0.0, 1.0);
    widget.onDragProgress?.call(_animateController.value);
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.stopDrag;

    return Listener(
      onPointerMove: active ? _onPointerMove : null,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onVerticalDragStart: active ? _handleDragStart : null,
        onVerticalDragEnd: active ? _handleDragEnd : null,
        child: AnimatedBuilder(
          animation: _animateController,
          builder: (context, _) => FadeTransition(
            opacity: _opacityAnimation,
            child: SlideTransition(
              position: _moveAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
