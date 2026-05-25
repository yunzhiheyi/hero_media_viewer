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
            '单图预览',
            '点击缩略图展开全屏预览，支持缩放和拖拽关闭',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SingleImageDemo()),
            ),
          ),
          _buildSection(
            context,
            '多图 Swiper',
            '左右滑动切换图片，支持缩放和拖拽关闭',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GalleryDemo()),
            ),
          ),
          _buildSection(
            context,
            '视频播放',
            '全屏播放视频，支持拖拽关闭',
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VideoDemo()),
            ),
          ),
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

class SingleImageDemo extends StatelessWidget {
  const SingleImageDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const heroTag = 'single-image-0';

    return Scaffold(
      appBar: AppBar(title: const Text('单图预览')),
      body: Center(
        child: GestureDetector(
          onTap: () {
            showImageHero(
              context: context,
              imageSource: imageUrls[0],
              heroTag: heroTag,
            );
          },
          child: Hero(
            tag: heroTag,
            child: Container(
              width: 150,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(imageUrls[0]),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(Icons.zoom_in, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GalleryDemo extends StatelessWidget {
  const GalleryDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('多图 Swiper')),
      body: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          final heroTag = 'gallery-image-$index';

          return GestureDetector(
            onTap: () {
              showImageGallery(
                context: context,
                imageSources: imageUrls,
                heroTags: List.generate(
                  imageUrls.length,
                  (i) => 'gallery-image-$i',
                ),
                initialIndex: index,
                showIndicator: false,
              );
            },
            child: Hero(
              tag: heroTag,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                  image: DecorationImage(
                    image: NetworkImage(imageUrls[index]),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class VideoDemo extends StatelessWidget {
  const VideoDemo({super.key});

  @override
  Widget build(BuildContext context) {
    const heroTag = 'video-0';

    return Scaffold(
      appBar: AppBar(title: const Text('视频播放')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              VideoHeroThumbnailToZoom(
                videoSource: videoUrl,
                thumbnail: videoThumbnail,
                heroTag: heroTag,
                width: 110,
                height: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                '点击播放网络视频',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
