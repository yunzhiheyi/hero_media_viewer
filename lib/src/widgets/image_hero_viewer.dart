import 'dart:async';

import 'package:flutter/material.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';

void showImageHeroOverlay({
  required BuildContext context,
  required dynamic imageSource,
  required Rect startRect,
  VoidCallback? onClose,
  double? aspectRatio,
  bool fullScreen = true,
  HeroOverlayController? controller,
  BoxFit thumbnailFit = BoxFit.contain,
  Alignment thumbnailAlignment = Alignment.center,
  Widget Function(
    BuildContext context,
    ImageProvider imageProvider,
    bool isFocus,
  )? imageBuilder,
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  final imageProvider = MediaSource.from(imageSource);
  final overlayController = controller ?? HeroOverlayController();

  void open(double resolvedAspectRatio) {
    showHeroOverlay(
      context: context,
      startRect: startRect,
      aspectRatio: resolvedAspectRatio,
      fullScreen: fullScreen,
      controller: overlayController,
      onClose: onClose,
      foregroundBuilder: foregroundBuilder,
      closeBuilder: (context, index, progress) {
        return Image(
          image: imageProvider,
          fit: thumbnailFit,
          alignment: thumbnailAlignment,
        );
      },
      dragBuilder: (
        BuildContext context,
        HeroOverlayDragHandlers dragHandlers,
      ) {
        return InteractiveGalleryViewer(
          sources: [imageProvider],
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
            if (imageBuilder != null) {
              return imageBuilder(context, imageProvider, isFocus);
            }
            return Center(
              child: Image(image: imageProvider, fit: BoxFit.contain),
            );
          },
        );
      },
    );
  }

  if (aspectRatio != null) {
    open(aspectRatio);
    return;
  }

  unawaited(
    _resolveImageAspectRatio(imageProvider).then((resolvedAspectRatio) {
      if (!context.mounted) return;
      open(resolvedAspectRatio ?? _rectAspectRatio(startRect));
    }),
  );
}

Future<double?> _resolveImageAspectRatio(ImageProvider imageProvider) {
  final completer = Completer<double?>();
  final stream = imageProvider.resolve(ImageConfiguration.empty);
  late ImageStreamListener listener;

  listener = ImageStreamListener(
    (info, _) {
      final width = info.image.width;
      final height = info.image.height;
      stream.removeListener(listener);
      completer.complete(height == 0 ? null : width / height);
    },
    onError: (error, stackTrace) {
      stream.removeListener(listener);
      completer.complete(null);
    },
  );

  stream.addListener(listener);

  return completer.future.timeout(
    const Duration(milliseconds: 250),
    onTimeout: () {
      stream.removeListener(listener);
      return null;
    },
  );
}

double _rectAspectRatio(Rect rect) {
  if (rect.height <= 0) {
    return 1.0;
  }
  return rect.width / rect.height;
}
