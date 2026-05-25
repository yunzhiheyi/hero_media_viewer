import 'package:flutter/material.dart';
import 'hero_dialog_route.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';

void showImageGallery({
  required BuildContext context,
  required List<dynamic> imageSources,
  required List<String> heroTags,
  int initialIndex = 0,
  bool showIndicator = true,
  void Function(int index)? onPageChanged,
  VoidCallback? onClose,
}) {
  final imageProviders =
      imageSources.map((source) => MediaSource.from(source)).toList();

  Navigator.of(context).push(
    HeroDialogRoute<void>(
      builder:
          (BuildContext context) => InteractiveGalleryViewer(
            sources: imageProviders,
            initIndex: initialIndex,
            enableIndicator: showIndicator,
            onPageChanged: onPageChanged,
            itemBuilder: (BuildContext context, int index, bool isFocus) {
              return _HeroImageContent(
                imageProvider: imageProviders[index],
                heroTag: heroTags[index],
              );
            },
          ),
    ),
  );
}

class _HeroImageContent extends StatelessWidget {
  final ImageProvider imageProvider;
  final String heroTag;

  const _HeroImageContent({required this.imageProvider, required this.heroTag});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Hero(
        tag: heroTag,
        child: Image(image: imageProvider, fit: BoxFit.contain),
      ),
    );
  }
}
