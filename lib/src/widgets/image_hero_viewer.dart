import 'dart:async';

import 'package:flutter/material.dart';

import '../core/image_aspect_ratio.dart';
import '../core/media_source.dart';
import 'animated_fit_image.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';

/// 单图 hero overlay 自定义构建器（替换默认 `Image(fit: contain)`）。
typedef SingleImageBuilder =
    Widget Function(
      BuildContext context,
      ImageProvider imageProvider,
      bool isFocus,
    );

/// 打开单图 hero overlay。
///
/// 流程：测量缩略图 [startRect] → 异步解析图片真实宽高比 → 展开到目标矩形。
/// 解析超时（250ms）或失败时退化为 [startRect] 的宽高比。
///
/// 自定义：
/// - [imageBuilder]：替换默认图片渲染（如换 `CachedNetworkImage`、加水印）。
/// - [foregroundBuilder]：在 overlay 之上叠加自定义层（保存按钮、说明字等）。
void showImageHeroOverlay({
  required BuildContext context,
  required dynamic imageSource,
  required Rect startRect,
  VoidCallback? onClose,
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  BoxFit thumbnailFit = BoxFit.contain,
  Alignment thumbnailAlignment = Alignment.center,
  SingleImageBuilder? imageBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  final imageProvider = MediaSource.from(imageSource);
  final overlayController = controller ?? HeroOverlayController();

  void open(double resolvedAspectRatio) {
    final screenSize = MediaQuery.sizeOf(context);
    final startSize = startRect.size;
    final endSize =
        fullScreen
            ? screenSize
            : _containedTargetSize(resolvedAspectRatio, screenSize);

    showHeroOverlay(
      context: context,
      startRect: startRect,
      aspectRatio: resolvedAspectRatio,
      fullScreen: fullScreen,
      controller: overlayController,
      onClose: onClose,
      dimBackdropOnDrag: true,
      foregroundBuilder: foregroundBuilder,
      openBuilder:
          (_, __, progress) => AnimatedFitImage(
            image: imageProvider,
            aspectRatio: resolvedAspectRatio,
            progress: progress,
            startFit: thumbnailFit,
            endFit: BoxFit.contain,
            startContainerSize: startSize,
            endContainerSize: endSize,
          ),
      closeBuilder:
          (_, __, progress) => AnimatedFitImage(
            image: imageProvider,
            aspectRatio: resolvedAspectRatio,
            progress: 1.0 - progress,
            startFit: thumbnailFit,
            endFit: BoxFit.contain,
            startContainerSize: startSize,
            endContainerSize: endSize,
          ),
      dragBuilder:
          (ctx, dragHandlers) => InteractiveGalleryViewer(
            sources: [imageProvider],
            initIndex: 0,
            isSingle: true,
            showBackground: false,
            showAppBar: false,
            tapToDismiss: false,
            dismissEnabled: false,
            externalVerticalDragStart: dragHandlers.onStart,
            externalVerticalDragUpdate: dragHandlers.onUpdate,
            externalVerticalDragEnd: dragHandlers.onEnd,
            itemBuilder:
                (c, _, isFocus) =>
                    imageBuilder?.call(c, imageProvider, isFocus) ??
                    Center(
                      child: Image(image: imageProvider, fit: BoxFit.contain),
                    ),
          ),
    );
  }

  if (aspectRatio != null) {
    open(aspectRatio);
    return;
  }

  unawaited(
    resolveImageAspectRatio(imageProvider).then((resolved) {
      if (!context.mounted) return;
      open(resolved ?? rectAspectRatio(startRect));
    }),
  );
}

/// 非 fullScreen 模式下，按宽高比居中放大并 fit 进屏幕的目标尺寸。
/// 与 [_HeroOverlayViewState._calculateTargetRect] 逻辑一致。
Size _containedTargetSize(double aspectRatio, Size screen) {
  var w = screen.width;
  var h = w / aspectRatio;
  if (h > screen.height) {
    h = screen.height;
    w = h * aspectRatio;
  }
  return Size(w, h);
}
