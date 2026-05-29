import 'dart:async';

import 'package:flutter/material.dart';

import '../core/image_aspect_ratio.dart';
import '../core/media_source.dart';
import 'animated_fit_image.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';

/// 多图画廊 hero overlay 的自定义图片构建器。
typedef GalleryImageBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
  int index,
  bool isFocus,
);

/// 打开多图 swipe 画廊 overlay。
///
/// 流程：从 [startRect] 展开 → 内置 PageView 左右滑动 → 点击/下拉关闭。
/// 默认按 [imageSources] 第一项的真实宽高比展开（异步解析，超时退化为 startRect）。
///
/// 自定义：
/// - [imageBuilder]：替换默认图片渲染（每页可获取 index 和 isFocus）。
/// - [foregroundBuilder]：在 overlay 之上叠加；若 [showIndicator] 为 true，
///   内置指示器会用 `Stack` 与之共存。
/// - [itemRects]：每张图原始位置矩形，切页时关闭动画回到对应缩略图。
void showImageGalleryOverlay({
  required BuildContext context,
  required List<dynamic> imageSources,
  required Rect startRect,
  int initialIndex = 0,
  bool showIndicator = true,
  Map<int, Rect>? itemRects,
  void Function(int index)? onPageChanged,
  VoidCallback? onClose,
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  BoxFit thumbnailFit = BoxFit.cover,
  Alignment thumbnailAlignment = Alignment.center,
  GalleryImageBuilder? imageBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  _validateSources(imageSources, initialIndex);

  final providers =
      imageSources.map((s) => MediaSource.from(s)).toList(growable: false);
  final currentIndex = ValueNotifier<int>(initialIndex);

  // 每张图的真实宽高比；后台并发解析，closeBuilder / 翻页 target rect 用到。
  final resolvedRatios = <int, double>{};

  void open(double initialAspectRatio) {
    final screenSize = MediaQuery.sizeOf(context);
    final startSize = startRect.size;
    final endSize = fullScreen
        ? screenSize
        : _containedTargetSize(initialAspectRatio, screenSize);

    showHeroOverlay(
      context: context,
      startRect: startRect,
      aspectRatio: initialAspectRatio,
      fullScreen: fullScreen,
      itemRects: itemRects,
      initialIndex: initialIndex,
      currentIndexListenable: currentIndex,
      controller: controller,
      onClose: onClose,
      itemAspectRatios: resolvedRatios,
      foregroundBuilder: _mergedForeground(
        showIndicator: showIndicator && providers.length > 1,
        count: providers.length,
        userForeground: foregroundBuilder,
      ),
      openBuilder: (_, index, progress) => AnimatedFitImage(
        image: providers[index],
        aspectRatio: resolvedRatios[index] ?? initialAspectRatio,
        progress: progress,
        startFit: thumbnailFit,
        endFit: BoxFit.contain,
        startContainerSize: startSize,
        endContainerSize: endSize,
      ),
      closeBuilder: (_, index, progress) => AnimatedFitImage(
        image: providers[index],
        aspectRatio: resolvedRatios[index] ?? initialAspectRatio,
        progress: 1.0 - progress,
        startFit: thumbnailFit,
        endFit: BoxFit.contain,
        startContainerSize: startSize,
        endContainerSize: endSize,
      ),
      dragBuilder: (ctx, dragHandlers) => InteractiveGalleryViewer(
        sources: providers,
        initIndex: initialIndex,
        enableIndicator: false,
        showBackground: false,
        showAppBar: false,
        tapToDismiss: false,
        dismissEnabled: false,
        externalVerticalDragStart: dragHandlers.onStart,
        externalVerticalDragUpdate: dragHandlers.onUpdate,
        externalVerticalDragEnd: dragHandlers.onEnd,
        onPageChanged: (i) {
          currentIndex.value = i;
          onPageChanged?.call(i);
        },
        itemBuilder: (c, index, isFocus) =>
            imageBuilder?.call(c, providers[index], index, isFocus) ??
            Center(child: Image(image: providers[index], fit: BoxFit.contain)),
      ),
    );
  }

  if (aspectRatio != null) {
    resolvedRatios[initialIndex] = aspectRatio;
    open(aspectRatio);
    // 后台解析其余图片
    for (var i = 0; i < providers.length; i++) {
      if (i == initialIndex) continue;
      unawaited(resolveImageAspectRatio(providers[i]).then((r) {
        if (r != null) resolvedRatios[i] = r;
      }));
    }
    return;
  }

  unawaited(resolveImageAspectRatio(providers[initialIndex]).then((resolved) {
    if (!context.mounted) return;
    final initialRatio = resolved ?? rectAspectRatio(startRect);
    resolvedRatios[initialIndex] = initialRatio;
    // 后台解析其余图片
    for (var i = 0; i < providers.length; i++) {
      if (i == initialIndex) continue;
      unawaited(resolveImageAspectRatio(providers[i]).then((r) {
        if (r != null) resolvedRatios[i] = r;
      }));
    }
    open(initialRatio);
  }));
}

/// 非 fullScreen 模式下，按宽高比居中放大并 fit 进屏幕的目标尺寸。
Size _containedTargetSize(double aspectRatio, Size screen) {
  var w = screen.width;
  var h = w / aspectRatio;
  if (h > screen.height) {
    h = screen.height;
    w = h * aspectRatio;
  }
  return Size(w, h);
}

/// 合并"内置指示器"与"用户 foregroundBuilder"：
/// - 都没有 → 返回 null（不创建 foreground 层）
/// - 只有一个 → 直接返回
/// - 两个都有 → 用 [Stack] 叠加，指示器位于下层（用户自定义浮层在上）
HeroOverlayForegroundBuilder? _mergedForeground({
  required bool showIndicator,
  required int count,
  HeroOverlayForegroundBuilder? userForeground,
}) {
  if (!showIndicator) return userForeground;
  if (userForeground == null) {
    return (c, i) => HeroOverlayPageIndicator(count: count, index: i);
  }
  return (c, i) => Stack(
        children: [
          HeroOverlayPageIndicator(count: count, index: i),
          userForeground(c, i),
        ],
      );
}

void _validateSources(List<dynamic> sources, int initialIndex) {
  if (sources.isEmpty) {
    throw ArgumentError.value(
      sources,
      'imageSources',
      'imageSources must not be empty.',
    );
  }
  if (initialIndex < 0 || initialIndex >= sources.length) {
    throw RangeError.range(
      initialIndex,
      0,
      sources.length - 1,
      'initialIndex',
    );
  }
}
