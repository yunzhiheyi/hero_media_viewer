/// Hero Media Viewer
///
/// A Flutter module for hero-style image and video preview with overlay animation.
///
/// Features:
/// - Overlay-based single image preview with zoom support
/// - Overlay-based image gallery with swipe support
/// - Overlay-based video playback with hero animation
/// - Mixed image and video gallery
/// - Arbitrary page overlay with hero open and drag-to-close animation
/// - Smooth open/close and drag-to-dismiss animations
/// - Support for network, local file, asset, and memory resources
library;

export 'src/widgets/hero_overlay.dart';
export 'src/widgets/image_hero_viewer.dart';
export 'src/widgets/image_gallery_viewer.dart';
export 'src/widgets/video_hero_viewer.dart';
export 'src/widgets/gallery_thumbnail.dart';
export 'src/models/media_item.dart';
export 'src/core/media_source.dart';
export 'src/core/hero_overlay_controller.dart';
