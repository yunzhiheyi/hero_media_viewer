import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hero_media_viewer/hero_media_viewer.dart';
import 'package:hero_media_viewer/src/widgets/interactive_gallery_viewer.dart';

void main() {
  test('MediaSource creates image providers from supported sources', () {
    expect(
      MediaSource.from('https://example.com/image.jpg'),
      isA<NetworkImage>(),
    );
    expect(MediaSource.from('assets://images/sample.png'), isA<AssetImage>());
    expect(
      MediaSource.from(Uint8List.fromList(<int>[1, 2, 3])),
      isA<MemoryImage>(),
    );
  });

  testWidgets(
    'InteractiveGalleryViewer renders multiple pages with indicator',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: InteractiveGalleryViewer<String>(
            sources: const ['one', 'two'],
            initIndex: 0,
            enableIndicator: true,
            itemBuilder: (context, index, isFocus) {
              return Center(child: Text('page-$index'));
            },
          ),
        ),
      );

      expect(find.text('page-0'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    },
  );

  testWidgets('Hero overlay can hide its default close button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Center(
                child: ElevatedButton(
                  onPressed:
                      () => showHeroOverlay(
                        context: context,
                        startRect: const Rect.fromLTWH(100, 100, 80, 80),
                        showCloseButton: false,
                        builder:
                            (_, _) => const ColoredBox(color: Colors.black),
                      ),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byIcon(Icons.close), findsNothing);
  });

  testWidgets('Hero overlay drags media without shrinking and fades backdrop', (
    tester,
  ) async {
    late HeroOverlayDragHandlers dragHandlers;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder:
              (context) => Center(
                child: ElevatedButton(
                  onPressed:
                      () => showHeroOverlay(
                        context: context,
                        startRect: const Rect.fromLTWH(100, 100, 80, 80),
                        targetRect: const Rect.fromLTWH(80, 220, 200, 120),
                        fullScreen: false,
                        showCloseButton: false,
                        dragBuilder: (_, handlers) {
                          dragHandlers = handlers;
                          return const SizedBox(
                            key: ValueKey('drag-media'),
                            child: ColoredBox(color: Colors.white),
                          );
                        },
                      ),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    Color backdropColor() {
      final backdrop = tester.widget<Container>(
        find.byKey(const ValueKey('hero-overlay-backdrop')),
      );
      return backdrop.color!;
    }

    expect(backdropColor(), Colors.black);
    final initialRect = tester.getRect(
      find.byKey(const ValueKey('drag-media')),
    );

    dragHandlers.onStart(DragStartDetails(globalPosition: initialRect.center));
    dragHandlers.onUpdate(
      DragUpdateDetails(
        delta: const Offset(0, 100),
        globalPosition: initialRect.center + const Offset(0, 100),
      ),
    );
    await tester.pump();

    expect(backdropColor().a, greaterThan(0));
    expect(backdropColor().a, lessThan(Colors.black.a));
    final draggedRect = tester.getRect(
      find.byKey(const ValueKey('drag-media')),
    );
    expect(draggedRect.size, initialRect.size);

    dragHandlers.onEnd(DragEndDetails());
    await tester.pumpAndSettle();
    expect(backdropColor(), Colors.black);
  });
}
