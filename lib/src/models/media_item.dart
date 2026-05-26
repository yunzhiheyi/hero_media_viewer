// Media Item 数据模型

import 'package:flutter/material.dart';
import '../core/media_source.dart';

/// 媒体类型
enum MediaType { image, video }

/// 媒体项
class MediaItem {
  /// 唯一标识
  final String id;

  /// 媒体类型
  final MediaType type;

  /// 图片提供者（图片类型）
  final ImageProvider? imageProvider;

  /// 视频路径（视频类型）
  final String? videoPath;

  /// 缩略图
  final ImageProvider? thumbnail;

  /// 宽高比
  final double? aspectRatio;

  const MediaItem({
    required this.id,
    required this.type,
    this.imageProvider,
    this.videoPath,
    this.thumbnail,
    this.aspectRatio,
  });

  /// 创建图片项
  factory MediaItem.image({
    required String id,
    required ImageProvider imageProvider,
    ImageProvider? thumbnail,
    double? aspectRatio,
  }) {
    return MediaItem(
      id: id,
      type: MediaType.image,
      imageProvider: imageProvider,
      thumbnail: thumbnail,
      aspectRatio: aspectRatio,
    );
  }

  /// 通过动态图片资源创建图片项
  factory MediaItem.imageSource({
    required String id,
    required dynamic source,
    dynamic thumbnail,
    double? aspectRatio,
  }) {
    return MediaItem(
      id: id,
      type: MediaType.image,
      imageProvider: MediaSource.from(source),
      thumbnail: thumbnail == null ? null : MediaSource.from(thumbnail),
      aspectRatio: aspectRatio,
    );
  }

  /// 创建视频项
  factory MediaItem.video({
    required String id,
    required String videoPath,
    ImageProvider? thumbnail,
    double? aspectRatio,
  }) {
    return MediaItem(
      id: id,
      type: MediaType.video,
      videoPath: videoPath,
      thumbnail: thumbnail,
      aspectRatio: aspectRatio,
    );
  }

  /// 通过动态缩略图资源创建视频项
  factory MediaItem.videoSource({
    required String id,
    required String videoPath,
    dynamic thumbnail,
    double? aspectRatio,
  }) {
    return MediaItem(
      id: id,
      type: MediaType.video,
      videoPath: videoPath,
      thumbnail: thumbnail == null ? null : MediaSource.from(thumbnail),
      aspectRatio: aspectRatio,
    );
  }
}
