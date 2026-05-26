import 'package:flutter/material.dart';

typedef ScaleChanged = void Function(double scale);

class InteractiveViewerBoundary extends StatefulWidget {
  const InteractiveViewerBoundary({
    super.key,
    required this.child,
    required this.boundaryWidth,
    this.controller,
    this.onScaleChanged,
    this.onLeftBoundaryHit,
    this.onRightBoundaryHit,
    this.scaleEnabled = true,
    this.onNoBoundaryHit,
    this.maxScale = 3.5,
    this.minScale = 0.6,
    this.panEnabled = true,
  });

  final Widget child;
  final bool scaleEnabled;
  final double boundaryWidth;
  final TransformationController? controller;
  final ScaleChanged? onScaleChanged;
  final VoidCallback? onLeftBoundaryHit;
  final VoidCallback? onRightBoundaryHit;
  final VoidCallback? onNoBoundaryHit;
  final double maxScale;
  final double minScale;
  final bool panEnabled;

  @override
  State<InteractiveViewerBoundary> createState() =>
      InteractiveViewerBoundaryState();
}

class InteractiveViewerBoundaryState extends State<InteractiveViewerBoundary> {
  late TransformationController _controller;
  double? _scale;
  double? _effectiveBoundaryWidth;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TransformationController();
    _controller.addListener(_emitScaleChange);
  }

  void _emitScaleChange() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    if (_scale != currentScale) {
      _scale = currentScale;
      widget.onScaleChanged?.call(currentScale);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_emitScaleChange);
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateBoundaryDetection(ScaleEndDetails scaleEndDetails) {
    final double scale = _controller.value.getMaxScaleOnAxis();
    _emitScaleChange();

    if (scale <= widget.minScale + 0.01) {
      widget.onLeftBoundaryHit?.call();
      widget.onRightBoundaryHit?.call();
      return;
    }

    final double xOffset = _controller.value.getTranslation().x;
    final double boundaryWidth =
        _effectiveBoundaryWidth ?? widget.boundaryWidth;
    final double scaledWidth = boundaryWidth * scale;
    final double minOffset = boundaryWidth - scaledWidth;
    const double epsilon = 2.0;

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
        final screenSize = MediaQuery.of(context).size;
        final width =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : screenSize.width;
        final height =
            constraints.hasBoundedHeight
                ? constraints.maxHeight
                : screenSize.height;
        _effectiveBoundaryWidth = width;

        return InteractiveViewer(
          maxScale: widget.maxScale,
          minScale: widget.minScale,
          constrained: false,
          transformationController: _controller,
          onInteractionEnd: (details) => _updateBoundaryDetection(details),
          scaleEnabled: widget.scaleEnabled,
          panEnabled: widget.panEnabled,
          child: SizedBox(width: width, height: height, child: widget.child),
        );
      },
    );
  }
}
