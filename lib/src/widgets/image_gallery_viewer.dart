import 'dart:async';

import 'package:flutter/material.dart';
import 'hero_overlay.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';

void showImageGalleryOverlay({
  required BuildContext context,
  required List<dynamic> imageSources,
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
  HeroOverlayForegroundBuilder? foregroundBuilder,
}) {
  _validateImageSources(imageSources, initialIndex);

  final imageProviders =
      imageSources.map((source) => MediaSource.from(source)).toList();
  final currentIndex = ValueNotifier<int>(initialIndex);

  void open(double resolvedAspectRatio) {
    showHeroOverlay(
      context: context,
      startRect: startRect,
      aspectRatio: resolvedAspectRatio,
      fullScreen: fullScreen,
      itemRects: itemRects,
      initialIndex: initialIndex,
      currentIndexListenable: currentIndex,
      controller: controller,
      onClose: onClose,
      foregroundBuilder: _mergedForeground(
        showIndicator: showIndicator && imageProviders.length > 1,
        count: imageProviders.length,
        userForeground: foregroundBuilder,
      ),
      closeBuilder: (context, index, progress) {
        return Image(
          image: imageProviders[index],
          fit: thumbnailFit,
          alignment: thumbnailAlignment,
        );
      },
      dragBuilder: (
        BuildContext context,
        HeroOverlayDragHandlers dragHandlers,
      ) {
        return InteractiveGalleryViewer(
          sources: imageProviders,
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
            if (imageBuilder != null) {
              return imageBuilder(
                context,
                imageProviders[index],
                index,
                isFocus,
              );
            }
            return Center(
              child: Image(image: imageProviders[index], fit: BoxFit.contain),
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
    _resolveImageAspectRatio(imageProviders[initialIndex]).then((
      resolvedAspectRatio,
    ) {
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

void _validateImageSources(List<dynamic> imageSources, int initialIndex) {
  if (imageSources.isEmpty) {
    throw ArgumentError.value(
      imageSources,
      'imageSources',
      'imageSources must not be empty.',
    );
  }

  if (initialIndex < 0 || initialIndex >= imageSources.length) {
    throw RangeError.range(
      initialIndex,
      0,
      imageSources.length - 1,
      'initialIndex',
    );
  }
}
