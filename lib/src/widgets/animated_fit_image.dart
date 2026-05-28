import 'dart:math' as math;

import 'package:flutter/material.dart';

/// hero overlay 打开 / 关闭动画期间用的"渐变 BoxFit"图片。
///
/// 缩略图通常用 [BoxFit.cover]（填满裁切）、overlay 最终用 [BoxFit.contain]
/// （完整展示带黑边）。两种渲染下图片的视觉尺寸差异很大，直接做交叉淡入会看到
/// 图片"先变小再变大"的闪动。这里在每一帧都按当前容器大小重新计算 cover/contain
/// 的缩放因子，再 lerp 出当前 [progress] 对应的缩放，保证图片视觉上是平滑变化的。
///
/// - [progress]：0 表示完全使用 [startFit]（缩略图样式），1 表示完全使用 [endFit]
///   （overlay 样式）。
/// - [aspectRatio]：图片宽高比的"兜底值"。组件会在 initState 里订阅 [image] 的
///   ImageStream，图片实际解码后改用图片真实宽高比，避免 mama 的兜底（例如
///   缩略图容器的宽高比）与实际图片不匹配时出现"1:1 和 16:9 渲染成同一尺寸"的 bug。
/// - 容器外的部分会被 [ClipRect] 裁掉（与 BoxFit.cover 行为一致）。
class AnimatedFitImage extends StatefulWidget {
  const AnimatedFitImage({
    super.key,
    required this.image,
    required this.aspectRatio,
    required this.progress,
    this.startFit = BoxFit.cover,
    this.endFit = BoxFit.contain,
  });

  final ImageProvider image;
  final double aspectRatio;
  final double progress;
  final BoxFit startFit;
  final BoxFit endFit;

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

  /// 订阅 ImageStream；图片已经在 image cache 里时回调会同步触发。
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

    // 同步触发（首次订阅命中 cache）时，直接写字段，由后续首个 build 取用；
    // 异步触发（图片刚解码完）时，调度 post-frame 的 setState 重建。
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

        // 以 (aspect, 1) 作为图片的单位尺寸；cover/contain 的缩放系数即
        // "把单位图片塞进当前容器"所需的缩放。
        final coverScale = math.max(w / aspect, h);
        final containScale = math.min(w / aspect, h);

        final startScale = _scaleFor(widget.startFit, coverScale, containScale);
        final endScale = _scaleFor(widget.endFit, coverScale, containScale);
        final t = widget.progress.clamp(0.0, 1.0);
        final scale = startScale + (endScale - startScale) * t;

        final renderW = aspect * scale;
        final renderH = scale;
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

  static double _scaleFor(BoxFit fit, double cover, double contain) =>
      fit == BoxFit.cover ? cover : contain;
}
