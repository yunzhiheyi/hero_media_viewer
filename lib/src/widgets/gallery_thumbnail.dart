import 'package:flutter/material.dart';

import '../core/media_source.dart';
import 'hero_overlay.dart';
import 'image_hero_viewer.dart';
import 'video_hero_viewer.dart';

/// 视频缩略图组件。
///
/// 点击展开 hero overlay 播放视频，自带半透明遮罩 + 中央播放按钮。
/// 内部用 [GlobalKey] 自动测量自身位置作为 overlay 起始矩形，调用方无需手动传 heroTag。
class VideoHeroThumbnailToZoom extends StatelessWidget {
  const VideoHeroThumbnailToZoom({
    super.key,
    required this.videoSource,
    required this.thumbnail,
    this.width,
    this.height,
    this.borderRadius,
    this.playIconSize = 30,
    this.playIconColor,
    this.overlayOpacity = 0.3,
    this.onTap,
    this.thumbnailFit = BoxFit.cover,
  });

  /// 视频资源（http(s)、file://、绝对路径、assets://）。
  final String videoSource;

  /// 缩略图资源，支持 [MediaSource.from] 接受的所有类型。
  final dynamic thumbnail;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// 中央播放按钮大小。
  final double playIconSize;

  /// 中央播放按钮颜色，默认白色。
  final Color? playIconColor;

  /// 缩略图之上的半透明遮罩透明度（0~1）。
  final double overlayOpacity;

  /// 点击回调（在 overlay 打开之前触发）。
  final VoidCallback? onTap;

  /// 关闭动画时缩略图的填充模式。
  final BoxFit thumbnailFit;

  @override
  Widget build(BuildContext context) {
    final thumbnailKey = GlobalKey();
    final radius = borderRadius ?? BorderRadius.circular(8);

    return GestureDetector(
      onTap: () {
        onTap?.call();
        showVideoHeroOverlay(
          context: context,
          videoSource: videoSource,
          startRect: getWidgetGlobalRect(thumbnailKey),
          thumbnail: thumbnail,
          thumbnailFit: thumbnailFit,
        );
      },
      child: Container(
        key: thumbnailKey,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: radius,
          image: DecorationImage(
            image: MediaSource.from(thumbnail),
            fit: thumbnailFit,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: overlayOpacity),
            borderRadius: radius,
          ),
          child: Center(
            child: Icon(
              Icons.play_circle,
              color: playIconColor ?? Colors.white,
              size: playIconSize,
            ),
          ),
        ),
      ),
    );
  }
}

/// 图片缩略图组件。
///
/// 点击展开 hero overlay 预览图片（支持双指缩放、下滑关闭）。
/// 内部用 [GlobalKey] 自动测量自身位置作为 overlay 起始矩形。
class ImageHeroThumbnailToZoom extends StatelessWidget {
  const ImageHeroThumbnailToZoom({
    super.key,
    required this.imageSource,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
    this.thumbnailFit = BoxFit.contain,
  });

  /// 图片资源，支持 [MediaSource.from] 接受的所有类型。
  final dynamic imageSource;

  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// 点击回调（在 overlay 打开之前触发）。
  final VoidCallback? onTap;

  /// 关闭动画时缩略图的填充模式。
  final BoxFit thumbnailFit;

  @override
  Widget build(BuildContext context) {
    final thumbnailKey = GlobalKey();

    return GestureDetector(
      onTap: () {
        onTap?.call();
        showImageHeroOverlay(
          context: context,
          imageSource: imageSource,
          startRect: getWidgetGlobalRect(thumbnailKey),
          thumbnailFit: thumbnailFit,
        );
      },
      child: Container(
        key: thumbnailKey,
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          image: DecorationImage(
            image: MediaSource.from(imageSource),
            fit: thumbnailFit,
          ),
        ),
      ),
    );
  }
}
