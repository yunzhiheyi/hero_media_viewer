import 'dart:async';

import 'package:flutter/material.dart';

import '../core/image_aspect_ratio.dart';
import '../core/media_source.dart';
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

  void open(double resolvedAspectRatio) {
    showHeroOverlay(
      context: context,
      startRect: startRect,
      aspectRatio: resolvedAspectRatio,
      fullScreen: fullScreen,
      itemRects: itemRects,
      initialIndex: initialIndex,
      currentIndexListenable: currentIndex,
      controller: controller,
      onClose: onClose,
      foregroundBuilder: _mergedForeground(
        showIndicator: showIndicator && providers.length > 1,
        count: providers.length,
        userForeground: foregroundBuilder,
      ),
      // openBuilder / closeBuilder 用同一套缩略图渲染：避免 t=0 那一帧从 cover
      // 突变成 contain 引起尺寸闪烁。
      openBuilder: (_, index, __) => Image(
        image: providers[index],
        fit: thumbnailFit,
        alignment: thumbnailAlignment,
      ),
      closeBuilder: (_, index, __) => Image(
        image: providers[index],
        fit: thumbnailFit,
        alignment: thumbnailAlignment,
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
    open(aspectRatio);
    return;
  }

  unawaited(resolveImageAspectRatio(providers[initialIndex]).then((resolved) {
    if (!context.mounted) return;
    open(resolved ?? rectAspectRatio(startRect));
  }));
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
