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

  @override
  State<InteractiveViewerBoundary> createState() =>
      InteractiveViewerBoundaryState();
}

class InteractiveViewerBoundaryState extends State<InteractiveViewerBoundary> {
  late TransformationController _controller;
  double? _scale;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TransformationController();
    _controller.addListener(() {
      final currentScale = _controller.value.getMaxScaleOnAxis();
      if (currentScale < widget.minScale) {
        _controller.value = Matrix4.identity()..scale(widget.minScale);
      } else if (currentScale > widget.maxScale) {
        _controller.value = Matrix4.identity()..scale(widget.maxScale);
      }
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _updateBoundaryDetection(ScaleEndDetails scaleEndDetails) {
    final double scale = _controller.value.getMaxScaleOnAxis();

    if (_scale != scale) {
      _scale = scale;
      widget.onScaleChanged?.call(scale);
    }

    final double xOffset = _controller.value.row0[3];
    final double boundaryWidth = widget.boundaryWidth;
    final double boundaryEnd = boundaryWidth * scale;
    final double xPos = boundaryEnd + xOffset;

    if (boundaryEnd.round() == xPos.round()) {
      widget.onLeftBoundaryHit?.call();
    } else if (boundaryWidth.round() == xPos.round()) {
      widget.onRightBoundaryHit?.call();
    } else {
      widget.onNoBoundaryHit?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      constrained: false,
      transformationController: _controller,
      onInteractionEnd: (details) => _updateBoundaryDetection(details),
      scaleEnabled: widget.scaleEnabled,
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        child: widget.child,
      ),
    );
  }
}
