library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'hero_dialog_route.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';

void showVideoHero({
  required BuildContext context,
  required String videoSource,
  required String heroTag,
  dynamic thumbnail,
  VoidCallback? onClose,
}) {
  Navigator.of(context).push(
    HeroDialogRoute<void>(
      builder:
          (BuildContext context) => _VideoGalleryPage(
            videoSource: videoSource,
            heroTag: heroTag,
            thumbnail: thumbnail != null ? MediaSource.from(thumbnail) : null,
          ),
    ),
  );
}

class _VideoGalleryPage extends StatefulWidget {
  final String videoSource;
  final String heroTag;
  final ImageProvider? thumbnail;

  const _VideoGalleryPage({
    required this.videoSource,
    required this.heroTag,
    this.thumbnail,
  });

  @override
  State<_VideoGalleryPage> createState() => _VideoGalleryPageState();
}

class _VideoGalleryPageState extends State<_VideoGalleryPage> {
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
      } else {
        final path = MediaSource.toFilePath(widget.videoSource);
        _videoController = VideoPlayerController.file(File(path));
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
    return InteractiveGalleryViewer(
      sources: [widget.videoSource],
      initIndex: 0,
      isSingle: true,
      itemBuilder: (BuildContext context, int index, bool isFocus) {
        return GestureDetector(
          onTap: () {
            if (_videoController != null) {
              if (_videoController!.value.isPlaying) {
                _videoController!.pause();
              } else {
                _videoController!.play();
              }
            }
          },
          child: Hero(
            tag: widget.heroTag,
            placeholderBuilder: (context, heroSize, child) {
              return Opacity(opacity: 1.0, child: child);
            },
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
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                if (_hasError)
                  const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 48,
                        ),
                        SizedBox(height: 8),
                        Text('视频加载失败', style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  ),
                if (_videoReady)
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
          ),
        );
      },
    );
  }
}
