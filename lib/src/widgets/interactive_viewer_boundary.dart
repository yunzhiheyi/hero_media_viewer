import 'package:flutter/material.dart';

/// scale 变化回调签名（参数为当前缩放比例）。
typedef ScaleChanged = void Function(double scale);

/// 带左右边界检测的 [InteractiveViewer] 包装。
///
/// 在普通 [InteractiveViewer] 之上加了三件事：
/// 1. 实时把 scale 变化以 [onScaleChanged] 抛出（监听 controller，每帧都准）。
/// 2. 交互结束时判断当前 translation 是否在左/右边界，触发对应回调，
///    用于 gallery 切页：图片在左/右边时把 PageView 唤回去。
/// 3. 用 [LayoutBuilder] 把可视区域大小固定下来，使 [InteractiveViewer.constrained]
///    设为 false 后仍能正确响应屏幕尺寸。
class InteractiveViewerBoundary extends StatefulWidget {
  const InteractiveViewerBoundary({
    super.key,
    required this.child,
    required this.boundaryWidth,
    this.controller,
    this.onScaleChanged,
    this.onLeftBoundaryHit,
    this.onRightBoundaryHit,
    this.onNoBoundaryHit,
    this.scaleEnabled = true,
    this.panEnabled = true,
    this.maxScale = 3.5,
    this.minScale = 0.6,
  });

  /// 被缩放/平移的子组件。
  final Widget child;

  /// 屏幕宽度兜底值；[LayoutBuilder] 拿不到约束时使用。
  final double boundaryWidth;

  /// 共享变换控制器，为空时内部新建并自动 dispose。
  final TransformationController? controller;

  /// scale 实时回调（每次 matrix 变化都触发）。
  final ScaleChanged? onScaleChanged;

  /// 已缩放且 translation 触及左边界时触发。
  final VoidCallback? onLeftBoundaryHit;

  /// 已缩放且 translation 触及右边界时触发。
  final VoidCallback? onRightBoundaryHit;

  /// 已缩放但不在左右边界时触发（用于阻止 PageView 切页）。
  final VoidCallback? onNoBoundaryHit;

  final bool scaleEnabled;
  final bool panEnabled;
  final double maxScale;
  final double minScale;

  @override
  State<InteractiveViewerBoundary> createState() =>
      InteractiveViewerBoundaryState();
}

class InteractiveViewerBoundaryState extends State<InteractiveViewerBoundary> {
  late final TransformationController _controller =
      widget.controller ?? TransformationController();
  double? _lastEmittedScale;
  double? _effectiveBoundaryWidth;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_emitScaleChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_emitScaleChange);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  /// 实时向外抛出 scale 变化（去重，相同值不触发）。
  void _emitScaleChange() {
    final scale = _controller.value.getMaxScaleOnAxis();
    if (_lastEmittedScale == scale) return;
    _lastEmittedScale = scale;
    widget.onScaleChanged?.call(scale);
  }

  /// 交互结束时根据 translation 判定当前是否触及左/右边界。
  ///
  /// rest scale 视为同时触及左右两端（让 PageView 两个方向都能切）；
  /// 已放大时按 translation.x 判定。
  void _evaluateBoundary(ScaleEndDetails _) {
    _emitScaleChange();

    final scale = _controller.value.getMaxScaleOnAxis();
    if (scale <= widget.minScale + 0.01) {
      widget.onLeftBoundaryHit?.call();
      widget.onRightBoundaryHit?.call();
      return;
    }

    final width = _effectiveBoundaryWidth ?? widget.boundaryWidth;
    final xOffset = _controller.value.getTranslation().x;
    final minOffset = width - width * scale; // 图片右沿与屏幕右沿对齐时的 translation.x
    const epsilon = 2.0;

    if (xOffset >= -epsilon) {
      widget.onLeftBoundaryHit?.call();
    } else if (xOffset <= minOffset + epsilon) {
      widget.onRightBoundaryHit?.call();
    } else {
      widget.onNoBoundaryHit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context);
        final width = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : screen.width;
        final height = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screen.height;
        _effectiveBoundaryWidth = width;

        return InteractiveViewer(
          maxScale: widget.maxScale,
          minScale: widget.minScale,
          constrained: false,
          transformationController: _controller,
          scaleEnabled: widget.scaleEnabled,
          panEnabled: widget.panEnabled,
          onInteractionEnd: _evaluateBoundary,
          child: SizedBox(width: width, height: height, child: widget.child),
        );
      },
    );
  }
}
