import 'package:flutter/material.dart';
import '../core/media_source.dart';
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

  /// Hero 动画标签，必须唯一
  final String heroTag;

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

  const VideoHeroThumbnailToZoom({
    super.key,
    required this.videoSource,
    required this.thumbnail,
    required this.heroTag,
    this.width,
    this.height,
    this.borderRadius,
    this.playIconSize = 30,
    this.playIconColor,
    this.overlayOpacity = 0.3,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
        showVideoHero(
          context: context,
          videoSource: videoSource,
          heroTag: heroTag,
          thumbnail: thumbnail,
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            image: DecorationImage(
              image: MediaSource.from(thumbnail),
              fit: BoxFit.cover,
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

  /// Hero 动画标签，必须唯一
  final String heroTag;

  /// 容器宽度
  final double? width;

  /// 容器高度
  final double? height;

  /// 边框圆角
  final BorderRadius? borderRadius;

  /// 点击回调
  final VoidCallback? onTap;

  const ImageHeroThumbnailToZoom({
    super.key,
    required this.imageSource,
    required this.heroTag,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        onTap?.call();
        showImageHero(
          context: context,
          imageSource: imageSource,
          heroTag: heroTag,
        );
      },
      child: Hero(
        tag: heroTag,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            image: DecorationImage(
              image: MediaSource.from(imageSource),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}