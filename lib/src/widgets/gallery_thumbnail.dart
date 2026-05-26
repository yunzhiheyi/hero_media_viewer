import 'package:flutter/material.dart';
import '../core/media_source.dart';
import 'hero_overlay.dart';
import 'video_hero_viewer.dart';
import 'image_hero_viewer.dart';

/// 视频缩略图组件
///
/// 可点击的视频预览组件，点击后展开全屏播放，带播放按钮
class VideoHeroThumbnailToZoom extends StatelessWidget {
  /// 视频资源地址
  final String videoSource;

  /// 缩略图资源
  final dynamic thumbnail;

  /// 容器宽度
  final double? width;

  /// 容器高度
  final double? height;

  /// 边框圆角
  final BorderRadius? borderRadius;

  /// 播放图标大小
  final double playIconSize;

  /// 播放图标颜色
  final Color? playIconColor;

  /// 遮罩透明度
  final double overlayOpacity;

  /// 点击回调
  final VoidCallback? onTap;

  /// Overlay 关闭到缩略图时使用的图片填充方式
  final BoxFit thumbnailFit;

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

  @override
  Widget build(BuildContext context) {
    final thumbnailKey = GlobalKey();

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
          borderRadius: borderRadius ?? BorderRadius.circular(8),
          image: DecorationImage(
            image: MediaSource.from(thumbnail),
            fit: thumbnailFit,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: overlayOpacity),
            borderRadius: borderRadius ?? BorderRadius.circular(8),
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

/// 图片缩略图组件
///
/// 可点击的图片预览组件，点击后展开全屏预览（支持缩放）
class ImageHeroThumbnailToZoom extends StatelessWidget {
  /// 图片资源（支持网络、Asset、文件、内存）
  final dynamic imageSource;

  /// 容器宽度
  final double? width;

  /// 容器高度
  final double? height;

  /// 边框圆角
  final BorderRadius? borderRadius;

  /// 点击回调
  final VoidCallback? onTap;

  /// Overlay 关闭到缩略图时使用的图片填充方式
  final BoxFit thumbnailFit;

  const ImageHeroThumbnailToZoom({
    super.key,
    required this.imageSource,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
    this.thumbnailFit = BoxFit.contain,
  });

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
