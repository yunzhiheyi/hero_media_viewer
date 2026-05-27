library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';
import '../models/media_item.dart';

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
  Widget Function(
    BuildContext context,
    String videoSource,
    ImageProvider? thumbnail,
    bool isFocus,
  )? videoBuilder,
  Widget Function(
    BuildContext context,
    VideoPlayerController controller,
    bool isPlaying,
    VoidCallback togglePlayback,
  )? videoControlsBuilder,
  Widget Function(BuildContext context)? videoLoadingBuilder,
  Widget Function(BuildContext context)? videoErrorBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  final thumbnailProvider =
      thumbnail != null ? MediaSource.from(thumbnail) : null;

  showHeroOverlay(
    context: context,
    startRect: startRect,
    aspectRatio: aspectRatio ?? _rectAspectRatio(startRect),
    fullScreen: fullScreen,
    controller: controller,
    onClose: onClose,
    tapToClose: false,
    foregroundBuilder: foregroundBuilder,
    closeBuilder:
        thumbnailProvider != null
            ? (context, index, progress) {
              return Image(
                image: thumbnailProvider,
                fit: thumbnailFit,
                alignment: thumbnailAlignment,
              );
            }
            : null,
    dragBuilder: (BuildContext context, HeroOverlayDragHandlers dragHandlers) {
      return InteractiveGalleryViewer(
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
        itemBuilder: (BuildContext context, int index, bool isFocus) {
          if (videoBuilder != null) {
            return videoBuilder(context, videoSource, thumbnailProvider, isFocus);
          }
          return HeroVideoPlayer(
            videoSource: videoSource,
            thumbnail: thumbnailProvider,
            controlsBuilder: videoControlsBuilder,
            loadingBuilder: videoLoadingBuilder,
            errorBuilder: videoErrorBuilder,
          );
        },
      );
    },
  );
}

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
  Widget Function(
    BuildContext context,
    ImageProvider imageProvider,
    int index,
    bool isFocus,
  )? imageBuilder,
  Widget Function(
    BuildContext context,
    String videoSource,
    ImageProvider? thumbnail,
    int index,
    bool isFocus,
  )? videoBuilder,
  Widget Function(
    BuildContext context,
    VideoPlayerController controller,
    bool isPlaying,
    VoidCallback togglePlayback,
  )? videoControlsBuilder,
  Widget Function(BuildContext context)? videoLoadingBuilder,
  Widget Function(BuildContext context)? videoErrorBuilder,
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
    aspectRatio:
        aspectRatio ??
        items[initialIndex].aspectRatio ??
        _rectAspectRatio(startRect),
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
    closeBuilder: (context, index, progress) {
      final item = items[index];
      final imageProvider =
          item.type == MediaType.image ? item.imageProvider : item.thumbnail;

      if (imageProvider == null) {
        return const ColoredBox(color: Colors.black);
      }

      return Image(
        image: imageProvider,
        fit: thumbnailFit,
        alignment: thumbnailAlignment,
      );
    },
    dragBuilder: (BuildContext context, HeroOverlayDragHandlers dragHandlers) {
      return InteractiveGalleryViewer(
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
        onPageChanged: (index) {
          currentIndex.value = index;
          onPageChanged?.call(index);
        },
        itemBuilder: (BuildContext context, int index, bool isFocus) {
          final item = items[index];
          return switch (item.type) {
            MediaType.image => imageBuilder != null
                ? imageBuilder(
                    context,
                    _requiredImageProvider(item),
                    index,
                    isFocus,
                  )
                : Center(
                    child: Image(
                      image: _requiredImageProvider(item),
                      fit: BoxFit.contain,
                    ),
                  ),
            MediaType.video => videoBuilder != null
                ? videoBuilder(
                    context,
                    _requiredVideoPath(item),
                    item.thumbnail,
                    index,
                    isFocus,
                  )
                : HeroVideoPlayer(
                    videoSource: _requiredVideoPath(item),
                    thumbnail: item.thumbnail,
                    controlsBuilder: videoControlsBuilder,
                    loadingBuilder: videoLoadingBuilder,
                    errorBuilder: videoErrorBuilder,
                  ),
          };
        },
      );
    },
  );
}

HeroOverlayForegroundBuilder? _mergedForeground({
  required bool showIndicator,
  required int count,
  HeroOverlayForegroundBuilder? userForeground,
}) {
  if (!showIndicator && userForeground == null) return null;
  if (!showIndicator) return userForeground;
  if (userForeground == null) {
    return (context, index) =>
        HeroOverlayPageIndicator(count: count, index: index);
  }
  return (context, index) => Stack(
    children: [
      HeroOverlayPageIndicator(count: count, index: index),
      userForeground(context, index),
    ],
  );
}

double _rectAspectRatio(Rect rect) {
  if (rect.height <= 0) {
    return 1.0;
  }
  return rect.width / rect.height;
}

ImageProvider _requiredImageProvider(MediaItem item) {
  if (item.imageProvider == null) {
    throw ArgumentError.value(item, 'item', 'imageProvider is required.');
  }
  return item.imageProvider!;
}

String _requiredVideoPath(MediaItem item) {
  if (item.videoPath == null || item.videoPath!.isEmpty) {
    throw ArgumentError.value(item, 'item', 'videoPath is required.');
  }
  return item.videoPath!;
}

/// 默认的视频播放器组件，可通过 [controlsBuilder] / [loadingBuilder] / [errorBuilder]
/// 槽位 builder 自定义 UI；整库托管 VideoPlayerController 的初始化、释放和点击播放。
///
/// 若想完全替换播放器（例如换成 BetterPlayer），请使用 showXxxOverlay 的 `videoBuilder`
/// 参数自行返回 widget。
class HeroVideoPlayer extends StatefulWidget {
  final String videoSource;
  final ImageProvider? thumbnail;

  /// 自定义控件层（播放/暂停按钮、进度条等）。
  /// 接收当前 controller、播放状态和切换播放的回调。
  final Widget Function(
    BuildContext context,
    VideoPlayerController controller,
    bool isPlaying,
    VoidCallback togglePlayback,
  )?
  controlsBuilder;

  /// 自定义加载态 UI。
  final Widget Function(BuildContext context)? loadingBuilder;

  /// 自定义错误态 UI。
  final Widget Function(BuildContext context)? errorBuilder;

  const HeroVideoPlayer({
    super.key,
    required this.videoSource,
    this.thumbnail,
    this.controlsBuilder,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<HeroVideoPlayer> createState() => _HeroVideoPlayerState();
}

class _HeroVideoPlayerState extends State<HeroVideoPlayer> {
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() async {
    try {
      if (MediaSource.isNetwork(widget.videoSource)) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoSource),
        );
      } else if (MediaSource.isFile(widget.videoSource)) {
        final path = MediaSource.toFilePath(widget.videoSource);
        _videoController = VideoPlayerController.file(File(path));
      } else {
        final assetPath = widget.videoSource.replaceFirst('assets://', '');
        _videoController = VideoPlayerController.asset(assetPath);
      }

      await _videoController!.initialize();

      if (mounted) {
        setState(() {
          _videoReady = true;
        });
        _videoController!.play();
        _isPlaying = true;
        _videoController!.addListener(_videoListener);
      }
    } catch (e) {
      debugPrint('Video init failed: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  void _videoListener() {
    if (_videoController != null && mounted) {
      final isPlaying = _videoController!.value.isPlaying;
      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.removeListener(_videoListener);
    _videoController?.dispose();
    super.dispose();
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
          if (_videoReady)
            Center(
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
            ),
          if (!_videoReady && !_hasError)
            widget.loadingBuilder?.call(context) ??
                const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
          if (_hasError)
            widget.errorBuilder?.call(context) ??
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.white, size: 48),
                      SizedBox(height: 8),
                      Text('视频加载失败', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
          if (_videoReady)
            widget.controlsBuilder?.call(
                  context,
                  _videoController!,
                  _isPlaying,
                  _togglePlayback,
                ) ??
                Center(
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
                ),
        ],
      ),
    );
  }

  void _togglePlayback() {
    if (_videoController == null || !_videoReady) {
      return;
    }

    if (_videoController!.value.isPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
    }
  }
}
