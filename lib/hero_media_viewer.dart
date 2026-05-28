/// Hero Media Viewer
///
/// 基于 Overlay 的图片 / 视频 / 任意页面 hero 预览组件库。
///
/// 主要能力：
/// - 单图 / 多图画廊 overlay 预览（双指缩放、左右翻页、下滑关闭、缩略图回位动画）
/// - 单视频 overlay 播放（自动管理 controller，槽位可换 UI 或整个播放器内核）
/// - 图片视频混合画廊
/// - 任意 widget 的"卡片展开成全屏页面" hero 动画
/// - 资源协议自动识别：http(s)://、assets://、file://、绝对路径、Uint8List
library;

export 'src/core/hero_overlay_controller.dart';
export 'src/core/media_source.dart';
export 'src/models/media_item.dart';
export 'src/widgets/gallery_thumbnail.dart';
export 'src/widgets/hero_overlay.dart';
export 'src/widgets/image_gallery_viewer.dart';
export 'src/widgets/image_hero_viewer.dart';
export 'src/widgets/video_hero_viewer.dart';
