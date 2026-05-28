library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/image_aspect_ratio.dart';
import '../core/media_source.dart';
import '../models/media_item.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';

// ============================================================================
// Builder typedefs
// ============================================================================

/// 视频 item 完全自定义构建器（替换默认 [HeroVideoPlayer]）。
typedef HeroVideoItemBuilder = Widget Function(
  BuildContext context,
  String videoSource,
  ImageProvider? thumbnail,
  bool isFocus,
);

/// 混合画廊中的视频构建器，多 [index] 参数。
typedef HeroVideoIndexedItemBuilder = Widget Function(
  BuildContext context,
  String videoSource,
  ImageProvider? thumbnail,
  int index,
  bool isFocus,
);

/// 混合画廊中的图片构建器。
typedef HeroImageIndexedItemBuilder = Widget Function(
  BuildContext context,
  ImageProvider imageProvider,
  int index,
  bool isFocus,
);

/// [HeroVideoPlayer] 控件层槽位（替换默认的中央播放/暂停按钮）。
typedef HeroVideoControlsBuilder = Widget Function(
  BuildContext context,
  VideoPlayerController controller,
  bool isPlaying,
  VoidCallback togglePlayback,
);

/// [HeroVideoPlayer] 加载态/错误态槽位。
typedef HeroVideoStateBuilder = Widget Function(BuildContext context);

// ============================================================================
// Public APIs
// ============================================================================

/// 打开单视频 hero overlay。
///
/// 默认使用 [HeroVideoPlayer] 渲染（自动 init/play/dispose），可通过：
/// - [videoBuilder]：整个 item 由调用方接管（接 BetterPlayer 等第三方播放器）。
/// - [videoControlsBuilder] / [videoLoadingBuilder] / [videoErrorBuilder]：
///   只换 UI 槽位，保留内置 controller 生命周期。
/// - [foregroundBuilder]：在 overlay 之上叠加自定义层。
void showVideoHeroOverlay({
  required BuildContext context,
  required String videoSource,
  required Rect startRect,
  dynamic thumbnail,
  VoidCallback? onClose,
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  BoxFit thumbnailFit = BoxFit.cover,
  Alignment thumbnailAlignment = Alignment.center,
  HeroVideoItemBuilder? videoBuilder,
  HeroVideoControlsBuilder? videoControlsBuilder,
  HeroVideoStateBuilder? videoLoadingBuilder,
  HeroVideoStateBuilder? videoErrorBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  final thumbProvider =
      thumbnail == null ? null : MediaSource.from(thumbnail);

  showHeroOverlay(
    context: context,
    startRect: startRect,
    aspectRatio: aspectRatio ?? rectAspectRatio(startRect),
    fullScreen: fullScreen,
    controller: controller,
    onClose: onClose,
    tapToClose: false,
    foregroundBuilder: foregroundBuilder,
    closeBuilder: thumbProvider == null
        ? null
        : (_, __, ___) => Image(
              image: thumbProvider,
              fit: thumbnailFit,
              alignment: thumbnailAlignment,
            ),
    dragBuilder: (ctx, dragHandlers) => InteractiveGalleryViewer(
      sources: [videoSource],
      initIndex: 0,
      isSingle: true,
      showBackground: false,
      showAppBar: false,
      tapToDismiss: false,
      dismissEnabled: false,
      externalVerticalDragStart: dragHandlers.onStart,
      externalVerticalDragUpdate: dragHandlers.onUpdate,
      externalVerticalDragEnd: dragHandlers.onEnd,
      itemBuilder: (c, _, isFocus) =>
          videoBuilder?.call(c, videoSource, thumbProvider, isFocus) ??
          HeroVideoPlayer(
            videoSource: videoSource,
            thumbnail: thumbProvider,
            controlsBuilder: videoControlsBuilder,
            loadingBuilder: videoLoadingBuilder,
            errorBuilder: videoErrorBuilder,
          ),
    ),
  );
}

/// 打开混合媒体（图片 + 视频）画廊 overlay。
///
/// [items] 不能为空，[initialIndex] 在 [0, items.length) 范围内。
///
/// 自定义槽位与单视频版本一致，外加 [imageBuilder] 用于自定义图片渲染。
void showMediaHeroOverlay({
  required BuildContext context,
  required List<MediaItem> items,
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
  HeroImageIndexedItemBuilder? imageBuilder,
  HeroVideoIndexedItemBuilder? videoBuilder,
  HeroVideoControlsBuilder? videoControlsBuilder,
  HeroVideoStateBuilder? videoLoadingBuilder,
  HeroVideoStateBuilder? videoErrorBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  if (items.isEmpty) {
    throw ArgumentError.value(items, 'items', 'items must not be empty.');
  }
  if (initialIndex < 0 || initialIndex >= items.length) {
    throw RangeError.range(initialIndex, 0, items.length - 1, 'initialIndex');
  }

  final currentIndex = ValueNotifier<int>(initialIndex);

  showHeroOverlay(
    context: context,
    startRect: startRect,
    aspectRatio: aspectRatio ??
        items[initialIndex].aspectRatio ??
        rectAspectRatio(startRect),
    fullScreen: fullScreen,
    itemRects: itemRects,
    initialIndex: initialIndex,
    currentIndexListenable: currentIndex,
    controller: controller,
    onClose: onClose,
    tapToClose: false,
    foregroundBuilder: _mergedForeground(
      showIndicator: showIndicator && items.length > 1,
      count: items.length,
      userForeground: foregroundBuilder,
    ),
    closeBuilder: (_, index, __) {
      final item = items[index];
      final provider =
          item.type == MediaType.image ? item.imageProvider : item.thumbnail;
      if (provider == null) return const ColoredBox(color: Colors.black);
      return Image(
        image: provider,
        fit: thumbnailFit,
        alignment: thumbnailAlignment,
      );
    },
    dragBuilder: (ctx, dragHandlers) => InteractiveGalleryViewer(
      sources: items,
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
      itemBuilder: (c, index, isFocus) {
        final item = items[index];
        return switch (item.type) {
          MediaType.image => imageBuilder?.call(
                c,
                _requireImage(item),
                index,
                isFocus,
              ) ??
              Center(child: Image(image: _requireImage(item), fit: BoxFit.contain)),
          MediaType.video => videoBuilder?.call(
                c,
                _requireVideoPath(item),
                item.thumbnail,
                index,
                isFocus,
              ) ??
              HeroVideoPlayer(
                videoSource: _requireVideoPath(item),
                thumbnail: item.thumbnail,
                controlsBuilder: videoControlsBuilder,
                loadingBuilder: videoLoadingBuilder,
                errorBuilder: videoErrorBuilder,
              ),
        };
      },
    ),
  );
}

// ============================================================================
// Helpers
// ============================================================================

/// 合并内置指示器与用户自定义 foreground。规则见 [image_gallery_viewer._mergedForeground]。
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

ImageProvider _requireImage(MediaItem item) {
  final p = item.imageProvider;
  if (p == null) {
    throw ArgumentError.value(item, 'item', 'imageProvider is required.');
  }
  return p;
}

String _requireVideoPath(MediaItem item) {
  final p = item.videoPath;
  if (p == null || p.isEmpty) {
    throw ArgumentError.value(item, 'item', 'videoPath is required.');
  }
  return p;
}

// ============================================================================
// HeroVideoPlayer
// ============================================================================

/// 默认的 hero overlay 视频播放器组件。
///
/// 自动管理 [VideoPlayerController] 的初始化、播放和释放；点击切换播放/暂停，
/// 暂停时居中显示半透明播放按钮。
///
/// 自定义 UI 时，**优先**用槽位 builder 而不是替换整个 widget：
/// - [controlsBuilder]：替换中央播放按钮（拿到 controller 自己渲染进度条等）。
/// - [loadingBuilder] / [errorBuilder]：替换加载态 / 错误态 UI。
///
/// 想完全换播放器内核（BetterPlayer、Chewie 等）请使用 [showVideoHeroOverlay] /
/// [showMediaHeroOverlay] 的 `videoBuilder` 参数，自行负责生命周期。
class HeroVideoPlayer extends StatefulWidget {
  const HeroVideoPlayer({
    super.key,
    required this.videoSource,
    this.thumbnail,
    this.controlsBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  /// 视频地址：支持 http(s)://、file://、绝对路径、assets:// 或裸 asset 名。
  final String videoSource;

  /// 缩略图：未就绪时显示，与视频画面同位（BoxFit.contain）。
  final ImageProvider? thumbnail;

  /// 控件层自定义构建器（如自定义播放按钮 / 进度条）。
  final HeroVideoControlsBuilder? controlsBuilder;

  /// 加载态 UI 自定义构建器。
  final HeroVideoStateBuilder? loadingBuilder;

  /// 错误态 UI 自定义构建器。
  final HeroVideoStateBuilder? errorBuilder;

  @override
  State<HeroVideoPlayer> createState() => _HeroVideoPlayerState();
}

class _HeroVideoPlayerState extends State<HeroVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_onPlaybackTick)
      ..dispose();
    super.dispose();
  }

  /// 根据 [videoSource] 选择合适的 controller 构造器（网络/文件/asset），并启播。
  Future<void> _init() async {
    try {
      _controller = _buildController(widget.videoSource);
      await _controller!.initialize();
      if (!mounted) return;
      setState(() => _ready = true);
      _controller!
        ..addListener(_onPlaybackTick)
        ..play();
      _isPlaying = true;
    } catch (e) {
      debugPrint('HeroVideoPlayer init failed: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  VideoPlayerController _buildController(String source) {
    if (MediaSource.isNetwork(source)) {
      return VideoPlayerController.networkUrl(Uri.parse(source));
    }
    if (MediaSource.isFile(source)) {
      return VideoPlayerController.file(File(MediaSource.toFilePath(source)));
    }
    final assetPath =
        source.startsWith('assets://') ? source.substring(9) : source;
    return VideoPlayerController.asset(assetPath);
  }

  /// controller 监听：当 isPlaying 真实变化时同步 UI 状态。
  void _onPlaybackTick() {
    if (!mounted || _controller == null) return;
    final playing = _controller!.value.isPlaying;
    if (playing != _isPlaying) setState(() => _isPlaying = playing);
  }

  void _togglePlayback() {
    final c = _controller;
    if (c == null || !_ready) return;
    c.value.isPlaying ? c.pause() : c.play();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlayback,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.thumbnail != null)
            Positioned.fill(
              child: Image(image: widget.thumbnail!, fit: BoxFit.contain),
            ),
          if (_ready)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
          if (!_ready && !_hasError)
            widget.loadingBuilder?.call(context) ?? _defaultLoading(),
          if (_hasError) widget.errorBuilder?.call(context) ?? _defaultError(),
          if (_ready)
            widget.controlsBuilder?.call(
                  context,
                  _controller!,
                  _isPlaying,
                  _togglePlayback,
                ) ??
                _defaultControls(),
        ],
      ),
    );
  }

  Widget _defaultLoading() => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );

  Widget _defaultError() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.white, size: 48),
            SizedBox(height: 8),
            Text('视频加载失败', style: TextStyle(color: Colors.white)),
          ],
        ),
      );

  Widget _defaultControls() => Center(
        child: AnimatedOpacity(
          opacity: _isPlaying ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      );
}
