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
/// - [aspectRatio]：图片真实宽高比（宽 / 高），由 overlay 调用方异步解析后传入。
/// - 容器外的部分会被 [ClipRect] 裁掉（与 BoxFit.cover 行为一致）。
class AnimatedFitImage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        if (w <= 0 || h <= 0 || aspectRatio <= 0) {
          return const SizedBox.shrink();
        }

        // 以 (aspectRatio, 1) 作为图片的单位尺寸；cover/contain 的缩放系数即
        // "把单位图片塞进当前容器"所需的缩放。
        final coverScale = math.max(w / aspectRatio, h);
        final containScale = math.min(w / aspectRatio, h);

        final startScale = _scaleFor(startFit, coverScale, containScale);
        final endScale = _scaleFor(endFit, coverScale, containScale);
        final scale = startScale + (endScale - startScale) * progress.clamp(0.0, 1.0);

        final renderW = aspectRatio * scale;
        final renderH = 1.0 * scale;
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
                child: Image(image: image, fit: BoxFit.fill),
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
