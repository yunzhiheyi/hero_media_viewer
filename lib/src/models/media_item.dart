import 'package:flutter/material.dart';

import '../core/media_source.dart';

/// 媒体类型枚举。
enum MediaType { image, video }

/// 媒体项数据模型。
///
/// 用于 [showMediaHeroOverlay] 等接受混合媒体列表的 API。视频和图片各只
/// 用到一组字段：
/// - 图片项：[imageProvider] 必填，[thumbnail] 可选（关闭动画的占位图）。
/// - 视频项：[videoPath] 必填，[thumbnail] 强烈建议提供（视频未就绪时显示）。
class MediaItem {
  /// 业务唯一标识，用于去重/比对/keyed 列表。
  final String id;

  /// 当前媒体类型。
  final MediaType type;

  /// 图片资源（仅图片类型）。
  final ImageProvider? imageProvider;

  /// 视频路径或 URL（仅视频类型）。
  final String? videoPath;

  /// 缩略图：视频类型用于未就绪占位 + 关闭动画；图片类型用于关闭动画。
  final ImageProvider? thumbnail;

  /// 宽高比，提供后 overlay 打开动画可直接使用，避免异步解析。
  final double? aspectRatio;

  const MediaItem({
    required this.id,
    required this.type,
    this.imageProvider,
    this.videoPath,
    this.thumbnail,
    this.aspectRatio,
  });

  /// 由已构造的 [ImageProvider] 创建图片项。
  factory MediaItem.image({
    required String id,
    required ImageProvider imageProvider,
    ImageProvider? thumbnail,
    double? aspectRatio,
  }) =>
      MediaItem(
        id: id,
        type: MediaType.image,
        imageProvider: imageProvider,
        thumbnail: thumbnail,
        aspectRatio: aspectRatio,
      );

  /// 由动态 source（网络/asset/文件/内存）创建图片项，内部走 [MediaSource.from]。
  factory MediaItem.imageSource({
    required String id,
    required dynamic source,
    dynamic thumbnail,
    double? aspectRatio,
  }) =>
      MediaItem(
        id: id,
        type: MediaType.image,
        imageProvider: MediaSource.from(source),
        thumbnail: thumbnail == null ? null : MediaSource.from(thumbnail),
        aspectRatio: aspectRatio,
      );

  /// 由已构造的视频路径 + [ImageProvider] 缩略图创建视频项。
  factory MediaItem.video({
    required String id,
    required String videoPath,
    ImageProvider? thumbnail,
    double? aspectRatio,
  }) =>
      MediaItem(
        id: id,
        type: MediaType.video,
        videoPath: videoPath,
        thumbnail: thumbnail,
        aspectRatio: aspectRatio,
      );

  /// 由视频路径 + 动态缩略图 source 创建视频项，缩略图走 [MediaSource.from]。
  factory MediaItem.videoSource({
    required String id,
    required String videoPath,
    dynamic thumbnail,
    double? aspectRatio,
  }) =>
      MediaItem(
        id: id,
        type: MediaType.video,
        videoPath: videoPath,
        thumbnail: thumbnail == null ? null : MediaSource.from(thumbnail),
        aspectRatio: aspectRatio,
      );
}
