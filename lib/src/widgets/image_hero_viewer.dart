import 'package:flutter/material.dart';
import 'hero_dialog_route.dart';
import 'interactive_gallery_viewer.dart';
import '../core/media_source.dart';

void showImageHero({
  required BuildContext context,
  required dynamic imageSource,
  required String heroTag,
  VoidCallback? onClose,
}) {
  final imageProvider = MediaSource.from(imageSource);

  Navigator.of(context).push(
    HeroDialogRoute<void>(
      builder:
          (BuildContext context) => InteractiveGalleryViewer(
            sources: [imageProvider],
            initIndex: 0,
            isSingle: true,
            itemBuilder: (BuildContext context, int index, bool isFocus) {
              return _HeroImageContent(
                imageProvider: imageProvider,
                heroTag: heroTag,
              );
            },
          ),
    ),
  );
}

void showImageHeroWithProvider({
  required BuildContext context,
  required ImageProvider imageProvider,
  required String heroTag,
  VoidCallback? onClose,
}) {
  Navigator.of(context).push(
    HeroDialogRoute<void>(
      builder:
          (BuildContext context) => InteractiveGalleryViewer(
            sources: [imageProvider],
            initIndex: 0,
            isSingle: true,
            itemBuilder: (BuildContext context, int index, bool isFocus) {
              return _HeroImageContent(
                imageProvider: imageProvider,
                heroTag: heroTag,
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
