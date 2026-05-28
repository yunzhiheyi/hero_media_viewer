import 'dart:async';

import 'package:flutter/material.dart';

/// 从矩形计算宽高比，高度 ≤ 0 时退化为 1。
double rectAspectRatio(Rect rect) =>
    rect.height <= 0 ? 1.0 : rect.width / rect.height;

/// 解析 [ImageProvider] 的真实宽高比。
///
/// 用法：用于 overlay 打开前根据图片真实尺寸决定目标矩形；解析超时（默认 250ms）
/// 或失败返回 null，调用方应回退到 [rectAspectRatio] 或自定义值。
Future<double?> resolveImageAspectRatio(
  ImageProvider provider, {
  Duration timeout = const Duration(milliseconds: 250),
}) {
  final completer = Completer<double?>();
  final stream = provider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;

  listener = ImageStreamListener(
    (info, _) {
      stream.removeListener(listener);
      final h = info.image.height;
      completer.complete(h == 0 ? null : info.image.width / h);
    },
    onError: (_, __) {
      stream.removeListener(listener);
      completer.complete(null);
    },
  );
  stream.addListener(listener);

  return completer.future.timeout(timeout, onTimeout: () {
    stream.removeListener(listener);
    return null;
  });
}
