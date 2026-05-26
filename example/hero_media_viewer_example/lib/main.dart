import 'package:flutter/material.dart';
import 'package:hero_media_viewer/hero_media_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hero Media Viewer Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hero Media Viewer Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          _buildSection(
            context,
            'Overlay 单图预览',
            '固定缩略图展开，支持缩放和拖拽回位',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SingleImageOverlayDemo()),
            ),
          ),
          _buildSection(
            context,
            'Overlay 多图 Swiper',
            '多张图片滑动，底部安全区指示点',
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ImageGalleryOverlayDemo(),
              ),
            ),
          ),
          _buildSection(
            context,
            'Overlay 视频播放',
            '视频缩略图展开，点击切换播放暂停',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoOverlayDemo()),
            ),
          ),
          _buildSection(
            context,
            'Overlay 图片视频混合',
            '图片和视频混合滑动，统一回到当前缩略图',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MixedMediaOverlayDemo()),
            ),
          ),
          const _PageHeroEntrySection(),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    String description,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

const imageUrls = [
  'https://cdn.resste.com/upload/0b1613a9-466f-4f46-8cf9-dbc1ad36a37c.jpg~watermark',
  'https://cdn.resste.com/upload/3c9adc1d-b51e-4159-81cb-6fdf8b23184e.jpg~watermark',
  'https://cdn.resste.com/upload/e0fc96fe-9766-4317-bf8a-c5802fc08bee.jpg~watermark',
  'https://cdn.resste.com/upload/b6bef0aa-11ad-4bc8-be86-2bd877aaa757.jpg~watermark',
  'https://housebell-brighton.mypinata.cloud/ipfs/QmefruTcb6gT2b1JNYgvY2WvBhxtpwLbF1NUzkxTxpEtpC',
];

const videoUrl =
    'https://housebell-brighton.mypinata.cloud/ipfs/Qmaocf4Gqxnssd2HddGWuVcryWDf7oE9fvD1t9oxix5pg9?time=1772281331555';

const videoThumbnail =
    'https://housebell-brighton.mypinata.cloud/ipfs/QmefruTcb6gT2b1JNYgvY2WvBhxtpwLbF1NUzkxTxpEtpC';

class SingleImageOverlayDemo extends StatelessWidget {
  const SingleImageOverlayDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 单图预览')),
      body: Center(
        child: ImageHeroThumbnailToZoom(
          imageSource: imageUrls[1],
          width: 180,
          height: 120,
          thumbnailFit: BoxFit.cover,
        ),
      ),
    );
  }
}

class VideoOverlayDemo extends StatelessWidget {
  const VideoOverlayDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 视频播放')),
      body: const Center(
        child: VideoHeroThumbnailToZoom(
          videoSource: videoUrl,
          thumbnail: videoThumbnail,
          width: 160,
          height: 110,
        ),
      ),
    );
  }
}

class ImageGalleryOverlayDemo extends StatefulWidget {
  const ImageGalleryOverlayDemo({super.key});

  @override
  State<ImageGalleryOverlayDemo> createState() =>
      _ImageGalleryOverlayDemoState();
}

class _ImageGalleryOverlayDemoState extends State<ImageGalleryOverlayDemo> {
  late final List<GlobalKey> _itemKeys;

  @override
  void initState() {
    super.initState();
    _itemKeys = List.generate(imageUrls.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 多图 Swiper')),
      body: _MediaGrid(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return _ImageTile(
            key: _itemKeys[index],
            imageSource: imageUrls[index],
            onTap: () {
              showImageGalleryOverlay(
                context: context,
                imageSources: imageUrls,
                startRect: getWidgetGlobalRect(_itemKeys[index]),
                initialIndex: index,
                itemRects: _currentRects(_itemKeys),
                thumbnailFit: BoxFit.cover,
              );
            },
          );
        },
      ),
    );
  }
}

class MixedMediaOverlayDemo extends StatefulWidget {
  const MixedMediaOverlayDemo({super.key});

  @override
  State<MixedMediaOverlayDemo> createState() => _MixedMediaOverlayDemoState();
}

class _MixedMediaOverlayDemoState extends State<MixedMediaOverlayDemo> {
  late final List<GlobalKey> _itemKeys;
  late final List<MediaItem> _items;

  @override
  void initState() {
    super.initState();
    _items = [
      MediaItem.imageSource(id: 'image-0', source: imageUrls[0]),
      MediaItem.videoSource(
        id: 'video-0',
        videoPath: videoUrl,
        thumbnail: videoThumbnail,
      ),
      MediaItem.imageSource(id: 'image-1', source: imageUrls[2]),
      MediaItem.imageSource(id: 'image-2', source: imageUrls[4]),
    ];
    _itemKeys = List.generate(_items.length, (_) => GlobalKey());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 图片视频混合')),
      body: _MediaGrid(
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return switch (item.type) {
            MediaType.image => _ImageTile(
              key: _itemKeys[index],
              imageProvider: item.imageProvider!,
              onTap: () => _open(index),
            ),
            MediaType.video => _VideoTile(
              key: _itemKeys[index],
              thumbnail: item.thumbnail!,
              onTap: () => _open(index),
            ),
          };
        },
      ),
    );
  }

  void _open(int index) {
    showMediaHeroOverlay(
      context: context,
      items: _items,
      startRect: getWidgetGlobalRect(_itemKeys[index]),
      initialIndex: index,
      itemRects: _currentRects(_itemKeys),
      thumbnailFit: BoxFit.cover,
    );
  }
}

class PageHeroOverlayDemo extends StatefulWidget {
  const PageHeroOverlayDemo({super.key});

  @override
  State<PageHeroOverlayDemo> createState() => _PageHeroOverlayDemoState();
}

class _PageHeroOverlayDemoState extends State<PageHeroOverlayDemo> {
  final GlobalKey _cardKey = GlobalKey();
  final HeroOverlayController _overlayController = HeroOverlayController();

  @override
  void dispose() {
    _overlayController.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay 页面 Hero')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _openPageOverlay,
            child: _HideWhileFlying(
              controller: _overlayController,
              child: _PagePreviewCard(key: _cardKey),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '点击上面的卡片，会用 showHeroPageOverlay 展开一个完整页面。页面右上角关闭按钮和下滑关闭都会回到原卡片位置。',
          ),
        ],
      ),
    );
  }

  void _openPageOverlay() {
    _showPageHeroOverlay(context, _cardKey, _overlayController);
  }
}

class _PageHeroEntrySection extends StatefulWidget {
  const _PageHeroEntrySection();

  @override
  State<_PageHeroEntrySection> createState() => _PageHeroEntrySectionState();
}

class _PageHeroEntrySectionState extends State<_PageHeroEntrySection> {
  final GlobalKey _cardKey = GlobalKey();
  final HeroOverlayController _overlayController = HeroOverlayController();

  @override
  void dispose() {
    _overlayController.dismiss();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GestureDetector(
        onTap: () => _showPageHeroOverlay(context, _cardKey, _overlayController),
        child: _HideWhileFlying(
          controller: _overlayController,
          child: _PagePreviewCard(key: _cardKey),
        ),
      ),
    );
  }
}

void _showPageHeroOverlay(
  BuildContext context,
  GlobalKey cardKey,
  HeroOverlayController controller,
) {
  final detailCardKey = GlobalKey();

  showHeroPageOverlay(
    context: context,
    controller: controller,
    startRect: getWidgetGlobalRect(cardKey),
    closeRectBuilder: (_) => getWidgetGlobalRect(cardKey),
    dragBackdropOpacity: 0.4,
    sharedElementTargetRectBuilder: (_) {
      final r = getWidgetGlobalRect(detailCardKey);
      return r == Rect.zero ? _detailHeroCardRect(context) : r;
    },
    openBuilder: (context, index, progress) {
      return const _PagePreviewCardContent(compact: false, fill: true);
    },
    closeBuilder: (context, index, progress) {
      return const _PagePreviewCardContent(compact: false, fill: true);
    },
    builder: (context, controller, dragHandlers) {
      return _HeroPageDetailOverlay(
        controller: controller,
        dragHandlers: dragHandlers,
        cardKey: detailCardKey,
      );
    },
  );
}

class _HideWhileFlying extends StatelessWidget {
  final HeroOverlayController controller;
  final Widget child;

  const _HideWhileFlying({required this.controller, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: controller.sourceHidden,
      child: child,
      builder: (context, hidden, child) {
        return Visibility(
          visible: !hidden,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: child!,
        );
      },
    );
  }
}

Rect _detailHeroCardRect(BuildContext context) {
  // 兜底用的位置估算；首帧 GlobalKey 还没挂上时使用。
  // 这里用 viewPadding 而不是 padding，因为详情 overlay 不在 Scaffold 里，
  // 顶部 padding 不会被 AppBar 消耗。
  final viewPadding = MediaQuery.viewPaddingOf(context);
  final screenWidth = MediaQuery.sizeOf(context).width;
  return Rect.fromLTWH(16, viewPadding.top + 88, screenWidth - 32, 180);
}

class _PagePreviewCard extends StatelessWidget {
  const _PagePreviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: Colors.transparent,
      child: _PagePreviewCardContent(compact: false),
    );
  }
}

class _PagePreviewCardContent extends StatelessWidget {
  final bool compact;
  final bool fill;

  const _PagePreviewCardContent({
    super.key,
    required this.compact,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: fill ? double.infinity : (compact ? null : 180),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF102033),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: compact && !fill ? MainAxisSize.min : MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF35C2A4),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.article, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '页面 Hero 示例',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (!compact) ...[
            const Spacer(),
            const Text(
              '这个不是图片或视频资源，而是一个完整页面。',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Text(
                  '点击展开',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, color: Colors.white, size: 18),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroPageDetailOverlay extends StatelessWidget {
  final HeroOverlayController controller;
  final HeroOverlayDragHandlers dragHandlers;
  final GlobalKey? cardKey;

  const _HeroPageDetailOverlay({
    required this.controller,
    required this.dragHandlers,
    this.cardKey,
  });

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.of(context).padding;

    return Material(
      color: const Color(0xFFF7F8FA),
      child: Column(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: dragHandlers.onStart,
            onVerticalDragUpdate: dragHandlers.onUpdate,
            onVerticalDragEnd: dragHandlers.onEnd,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, padding.top + 10, 8, 12),
              color: Colors.white,
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '完整页面',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: controller.close,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                _PagePreviewCardContent(key: cardKey, compact: false),
                const SizedBox(height: 12),
                const _DetailBlock(
                  icon: Icons.touch_app,
                  title: '打开动画',
                  description: '从列表卡片的真实位置展开到全屏页面。',
                ),
                const _DetailBlock(
                  icon: Icons.swipe_down,
                  title: '拖动关闭',
                  description: '按住顶部区域向下拖动，松手超过阈值后回到原卡片。',
                ),
                const _DetailBlock(
                  icon: Icons.close,
                  title: '按钮关闭',
                  description: '点击右上角关闭按钮，也会执行同一套 Hero 回位动画。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _DetailBlock({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF35A88F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(description),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Map<int, Rect> _currentRects(List<GlobalKey> keys) {
  return {
    for (var i = 0; i < keys.length; i++) i: getWidgetGlobalRect(keys[i]),
  };
}

class _MediaGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const _MediaGrid({required this.itemCount, required this.itemBuilder});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}

class _ImageTile extends StatelessWidget {
  final dynamic imageSource;
  final ImageProvider? imageProvider;
  final VoidCallback onTap;

  const _ImageTile({
    super.key,
    this.imageSource,
    this.imageProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(
            image: imageProvider ?? MediaSource.from(imageSource),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final ImageProvider thumbnail;
  final VoidCallback onTap;

  const _VideoTile({super.key, required this.thumbnail, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          image: DecorationImage(image: thumbnail, fit: BoxFit.cover),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle, color: Colors.white, size: 42),
          ),
        ),
      ),
    );
  }
}
