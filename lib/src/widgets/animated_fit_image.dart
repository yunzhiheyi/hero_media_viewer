import 'dart:math' as math;

import 'package:flutter/material.dart';

/// hero overlay 打开 / 关闭动画期间用的"渐变 BoxFit"图片。
///
/// ## 核心思路
///
/// 缩略图通常用 [BoxFit.cover]（填满裁切）、overlay 最终用 [BoxFit.contain]
/// （完整展示带黑边）。如果每帧都拿**当前**容器大小计算 cover/contain 再 lerp，
/// 容器从小(180×120)到大(393×852)的过程中 cover 值会暴涨（受高度驱动），
/// 导致图片先变大后变小，产生视觉跳变。
///
/// 修正做法：在 t=0 和 t=1 时分别用**各自的容器大小**算出图片的绝对像素宽高，
/// 然后在整个动画中对这两组绝对值做线性插值。这样图片的视觉尺寸始终**单调变化**，
/// 实现类似微信图片预览的无缝放大效果。
///
/// ## 参数
///
/// - [progress]：0 → [startFit]（缩略图样式），1 → [endFit]（overlay 样式）。
/// - [startContainerSize] / [endContainerSize]：t=0 / t=1 时容器的像素尺寸。
///   提供后使用"绝对插值"算法；不提供则退化为每帧重算的旧算法（兼容已有调用方）。
/// - [aspectRatio]：图片宽高比兜底值。组件会订阅 [image] 的 ImageStream，
///   图片解码后改用真实宽高比。
/// - 容器外的部分会被 [ClipRect] 裁掉（与 BoxFit.cover 行为一致）。
class AnimatedFitImage extends StatefulWidget {
  const AnimatedFitImage({
    super.key,
    required this.image,
    required this.aspectRatio,
    required this.progress,
    this.startFit = BoxFit.cover,
    this.endFit = BoxFit.contain,
    this.startContainerSize,
    this.endContainerSize,
  });

  final ImageProvider image;
  final double aspectRatio;
  final double progress;
  final BoxFit startFit;
  final BoxFit endFit;

  /// t=0 时容器的像素尺寸（缩略图矩形）。
  /// 与 [endContainerSize] 同时提供才启用"绝对插值"。
  final Size? startContainerSize;

  /// t=1 时容器的像素尺寸（overlay 目标矩形）。
  final Size? endContainerSize;

  @override
  State<AnimatedFitImage> createState() => _AnimatedFitImageState();
}

class _AnimatedFitImageState extends State<AnimatedFitImage> {
  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// 图片解码后的真实宽高比；为空时退化用 [AnimatedFitImage.aspectRatio]。
  double? _resolvedAspect;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  @override
  void didUpdateWidget(covariant AnimatedFitImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) {
      _unsubscribe();
      _resolvedAspect = null;
      _subscribe();
    }
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _subscribe() {
    _stream = widget.image.resolve(ImageConfiguration.empty);
    _listener = ImageStreamListener(_onImage);
    _stream!.addListener(_listener!);
  }

  void _unsubscribe() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  void _onImage(ImageInfo info, bool _) {
    final h = info.image.height;
    if (h == 0) return;
    final aspect = info.image.width / h;
    if (_resolvedAspect == aspect) return;
    _resolvedAspect = aspect;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final aspect = _resolvedAspect ?? widget.aspectRatio;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0 || aspect <= 0) {
          return const SizedBox.shrink();
        }

        final t = widget.progress.clamp(0.0, 1.0);
        late final double renderW;
        late final double renderH;

        final startSize = widget.startContainerSize;
        final endSize = widget.endContainerSize;

        if (startSize != null && endSize != null) {
          // ── 绝对插值算法 ──────────────────────────────────────────
          // 用 t=0 和 t=1 各自的容器尺寸计算好图片的绝对像素大小，
          // 然后线性插值，保证整个动画中图片尺寸单调变化，不会先大后小。
          final startScale = _scaleForContainer(
            widget.startFit,
            aspect,
            startSize.width,
            startSize.height,
          );
          final endScale = _scaleForContainer(
            widget.endFit,
            aspect,
            endSize.width,
            endSize.height,
          );

          final startW = aspect * startScale;
          final startH = startScale;
          final endW = aspect * endScale;
          final endH = endScale;

          renderW = startW + (endW - startW) * t;
          renderH = startH + (endH - startH) * t;
        } else {
          // ── 旧算法（兼容不传 containerSize 的调用方）──────────────
          final coverScale = math.max(w / aspect, h);
          final containScale = math.min(w / aspect, h);
          final startScale =
              _scaleFor(widget.startFit, coverScale, containScale);
          final endScale =
              _scaleFor(widget.endFit, coverScale, containScale);
          final scale = startScale + (endScale - startScale) * t;
          renderW = aspect * scale;
          renderH = scale;
        }

        final left = (w - renderW) / 2;
        final top = (h - renderH) / 2;

        return ClipRect(
          child: Stack(
            children: [
              Positioned(
                left: left,
                top: top,
                width: renderW,
                height: renderH,
                child: Image(image: widget.image, fit: BoxFit.fill),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 给定容器尺寸和 fit 模式，计算图片的缩放因子。
  static double _scaleForContainer(
    BoxFit fit,
    double aspect,
    double containerW,
    double containerH,
  ) {
    final cover = math.max(containerW / aspect, containerH);
    final contain = math.min(containerW / aspect, containerH);
    return fit == BoxFit.cover ? cover : contain;
  }

  static double _scaleFor(BoxFit fit, double cover, double contain) =>
      fit == BoxFit.cover ? cover : contain;
}
