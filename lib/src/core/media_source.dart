import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';

/// 媒体资源类型
enum MediaSourceType { network, asset, file, memory }

/// 媒体资源工具类
///
/// 根据资源地址自动识别类型并返回对应的 ImageProvider
///
/// 支持的资源格式：
/// - 网络资源：http:// 或 https:// 开头
/// - Asset 资源：assets:// 开头
/// - 本地文件：file:// 开头或绝对路径
/// - 内存资源：直接传入 Uint8List
class MediaSource {
  /// 判断是否为 Windows 路径
  static bool _isWindowsPath(String path) {
    return RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(path);
  }

  /// 根据资源创建 ImageProvider
  ///
  /// [source] 支持：
  /// - String: URL/Asset路径/文件路径
  /// - Uint8List: 内存数据
  /// - ImageProvider: 直接返回
  static ImageProvider from(dynamic source) {
    if (source is ImageProvider) {
      return source;
    }

    if (source is Uint8List) {
      return MemoryImage(source);
    }

    if (source is String) {
      final path = source;

      // 网络资源
      if (path.startsWith('http://') || path.startsWith('https://')) {
        return NetworkImage(path);
      }

      // Asset 资源
      if (path.startsWith('assets://')) {
        return AssetImage(path.replaceFirst('assets://', ''));
      }

      // 文件 URI
      if (path.startsWith('file://')) {
        return FileImage(File(Uri.parse(path).toFilePath()));
      }

      // 本地文件路径
      if (path.startsWith('/') || _isWindowsPath(path)) {
        return FileImage(File(path));
      }

      // 默认当作 asset
      return AssetImage(path);
    }

    throw ArgumentError('Unsupported media source type: ${source.runtimeType}');
  }

  /// 获取资源类型
  static MediaSourceType typeOf(dynamic source) {
    if (source is Uint8List) {
      return MediaSourceType.memory;
    }

    if (source is String) {
      final path = source;

      if (path.startsWith('http://') || path.startsWith('https://')) {
        return MediaSourceType.network;
      }

      if (path.startsWith('assets://')) {
        return MediaSourceType.asset;
      }

      if (path.startsWith('file://') ||
          path.startsWith('/') ||
          _isWindowsPath(path)) {
        return MediaSourceType.file;
      }

      return MediaSourceType.asset;
    }

    return MediaSourceType.network;
  }

  /// 判断是否为网络资源
  static bool isNetwork(dynamic source) {
    if (source is String) {
      return source.startsWith('http://') || source.startsWith('https://');
    }
    return false;
  }

  /// 判断是否为本地文件
  static bool isFile(dynamic source) {
    if (source is String) {
      return source.startsWith('file://') ||
          source.startsWith('/') ||
          _isWindowsPath(source);
    }
    return false;
  }

  /// 判断是否为内存资源
  static bool isMemory(dynamic source) {
    return source is Uint8List;
  }

  /// 获取视频源路径
  ///
  /// 如果是 file:// URI，转换为文件路径
  /// 否则直接返回原路径（网络 URL 或本地路径）
  static String toFilePath(String source) {
    if (source.startsWith('file://')) {
      return Uri.parse(source).toFilePath();
    }
    return source;
  }
}

/// 向后兼容的顶层函数
ImageProvider createImageProvider(dynamic source) => MediaSource.from(source);
MediaSourceType getMediaSourceType(dynamic source) =>
    MediaSource.typeOf(source);
bool isNetworkSource(dynamic source) => MediaSource.isNetwork(source);
bool isFileSource(dynamic source) => MediaSource.isFile(source);
bool isMemorySource(dynamic source) => MediaSource.isMemory(source);
String getVideoSourcePath(String source) => MediaSource.toFilePath(source);
