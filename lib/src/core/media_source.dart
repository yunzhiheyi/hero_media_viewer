import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 媒体资源类型枚举。
enum MediaSourceType { network, asset, file, memory }

/// 媒体资源解析工具。
///
/// 根据资源字符串前缀或运行时类型自动判定来源类型，并构造对应的
/// [ImageProvider]。支持的 source 形式：
/// - 网络：`http://` / `https://` 开头的 String
/// - Asset：`assets://` 开头的 String（前缀会被剥离）
/// - 文件：`file://` URI、绝对路径（`/...`）、Windows 路径（`C:\...`）
/// - 内存：直接传入 [Uint8List]
/// - 直通：已是 [ImageProvider] 时原样返回
class MediaSource {
  const MediaSource._();

  /// 由 source 构造 [ImageProvider]。
  ///
  /// source 类型不被支持时抛出 [ArgumentError]。
  static ImageProvider from(dynamic source) {
    if (source is ImageProvider) return source;
    if (source is Uint8List) return MemoryImage(source);
    if (source is String) {
      if (_isNetwork(source)) return NetworkImage(source);
      if (source.startsWith('assets://')) {
        return AssetImage(source.substring('assets://'.length));
      }
      if (source.startsWith('file://')) {
        return FileImage(File(Uri.parse(source).toFilePath()));
      }
      if (_isLocalPath(source)) return FileImage(File(source));
      // 兜底当作 asset（无前缀）。
      return AssetImage(source);
    }
    throw ArgumentError('Unsupported media source type: ${source.runtimeType}');
  }

  /// 返回 source 对应的 [MediaSourceType]。
  static MediaSourceType typeOf(dynamic source) {
    if (source is Uint8List) return MediaSourceType.memory;
    if (source is String) {
      if (_isNetwork(source)) return MediaSourceType.network;
      if (source.startsWith('assets://')) return MediaSourceType.asset;
      if (source.startsWith('file://') || _isLocalPath(source)) {
        return MediaSourceType.file;
      }
      return MediaSourceType.asset;
    }
    return MediaSourceType.network;
  }

  /// 是否为网络资源（http/https）。
  static bool isNetwork(dynamic source) =>
      source is String && _isNetwork(source);

  /// 是否为本地文件资源（file:// 或绝对路径）。
  static bool isFile(dynamic source) =>
      source is String &&
      (source.startsWith('file://') || _isLocalPath(source));

  /// 是否为内存资源（[Uint8List]）。
  static bool isMemory(dynamic source) => source is Uint8List;

  /// 把 file:// URI 还原成本地路径；其它字符串原样返回。
  ///
  /// 视频播放器需要的是文件路径而非 URI，这里做一次归一化。
  static String toFilePath(String source) =>
      source.startsWith('file://') ? Uri.parse(source).toFilePath() : source;

  static bool _isNetwork(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  static bool _isLocalPath(String s) =>
      s.startsWith('/') || RegExp(r'^[a-zA-Z]:[/\\]').hasMatch(s);
}
