import 'dart:async';
import 'dart:io';

import 'package:brentv/local_media.dart';
import 'package:brentv/models/channel.dart';
import 'package:brentv/models/media_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class HeldDirectory extends Fake implements Directory {
  final Directory directory;
  final Completer<void> release;
  HeldDirectory(this.directory, this.release);
  @override
  Directory get absolute => this;
  @override
  String get path => directory.path;
  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) async* {
    await release.future;
    yield* directory.list(recursive: recursive, followLinks: followLinks);
  }
}

Future<void> loaded(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
  }
  fail('Folder listing did not finish');
}

/// Real file I/O completes between fake-clock pumps, one await per round.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
}

Future<Directory> fixture(WidgetTester tester) async {
  final directory = await tester.runAsync(
    () => Directory.systemTemp.createTemp('brentv-local-test-'),
  );
  addTearDown(() => directory!.delete(recursive: true));
  return directory!;
}

Widget page(
  Directory root, {
  Future<void> Function(BuildContext, Channel, List<Channel>)? onPlay,
}) => MaterialApp(
  home: LocalMediaPage(rootDirectory: root, onPlay: onPlay),
);

void main() {
  testWidgets(
    'lists one folder, sorts folders first, follows links, skips hidden and nonmedia',
    (tester) async {
      final root = await fixture(tester);
      await tester.runAsync(() async {
        final nested = await Directory('${root.path}/b Folder').create();
        await Directory('${root.path}/A Folder').create();
        await File('${nested.path}/Not scanned.mp4').writeAsString('fixture');
        for (final name in [
          'z movie.MKV',
          'A #? é.mp4',
          'a song.FLAC',
          'notes.txt',
          'mp4',
        ]) {
          await File('${root.path}/$name').writeAsString('fixture');
        }
        await Directory('${root.path}/.stfolder').create();
        await File('${root.path}/.hidden.mp4').writeAsString('fixture');
        await Link('${root.path}/outside').create(root.parent.path);
        await Link('${root.path}/linked.mp4').create('${root.path}/A #? é.mp4');
        await Link(
          '${root.path}/broken.mp4',
        ).create('${root.path}/missing.mp4');
      });
      await tester.pumpWidget(page(root));
      await loaded(tester);
      expect(
        tester
            .widgetList<ListTile>(find.byType(ListTile))
            .map((t) => (t.title! as Text).data),
        [
          'A Folder',
          'b Folder',
          'outside',
          'A #? é.mp4',
          'a song.FLAC',
          'linked.mp4',
          'z movie.MKV',
        ],
      );
      expect(find.text('Not scanned.mp4'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opens folders, Up and Escape return to Videos, then Back returns to Settings',
    (tester) async {
      final root = await fixture(tester);
      await tester.runAsync(() async {
        await Directory('${root.path}/Movies').create();
        await Directory('${root.path}/Series').create();
        await File(
          '${root.path}/Series/Episode 1.mp4',
        ).writeAsString('fixture');
      });
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: nav,
          home: const Scaffold(body: Text('Settings marker')),
        ),
      );
      nav.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => LocalMediaPage(rootDirectory: root),
        ),
      );
      await tester.pump();
      await loaded(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Series'));
      await loaded(tester);
      expect(find.text('Episode 1.mp4'), findsOneWidget);
      await tester.tap(find.text('Up'));
      await loaded(tester);
      expect(find.text('Series'), findsOneWidget);
      await tester.pump();
      // Focus returns to the folder Up came from, not the first entry.
      expect(
        (FocusManager.instance.primaryFocus?.context
                    ?.findAncestorWidgetOfExactType<ListTile>()
                    ?.title
                as Text?)
            ?.data,
        'Series',
      );
      await tester.tap(find.text('Series'));
      await loaded(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await loaded(tester);
      expect(find.text('Series'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pumpAndSettle();
      expect(find.text('Settings marker'), findsOneWidget);
    },
  );

  testWidgets(
    'passes encoded file URI and sorted transient siblings to playback',
    (tester) async {
      final root = await fixture(tester);
      final selected = File('${root.path}/B #? é video.MP4');
      await tester.runAsync(() async {
        await selected.writeAsString('fixture');
        await File('${root.path}/a audio.mp3').writeAsString('fixture');
        await Directory('${root.path}/folder').create();
      });
      Channel? played;
      List<Channel>? siblings;
      await tester.pumpWidget(
        page(
          root,
          onPlay: (_, channel, group) async {
            played = channel;
            siblings = group;
          },
        ),
      );
      await loaded(tester);
      await tester.tap(find.text('B #? é video.MP4'));
      for (var i = 0; i < 20 && played == null; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 5)),
        );
        await tester.pump();
      }
      expect(played?.url, selected.uri.toString());
      expect(Uri.parse(played!.url!).toFilePath(), selected.path);
      expect(siblings!.map((c) => c.name), ['a audio.mp3', 'B #? é video.MP4']);
      expect(
        siblings!.every(
          (c) =>
              c.transient &&
              c.id == null &&
              c.sourceId == 0 &&
              c.mediaType == MediaType.movie &&
              !c.favorite &&
              c.isPlayable,
        ),
        isTrue,
      );
      expect(identical(played, siblings!.last), isTrue);
    },
  );

  testWidgets('empty folder refresh discovers new files', (tester) async {
    final root = await fixture(tester);
    await tester.pumpWidget(page(root));
    await loaded(tester);
    expect(find.textContaining('No media here yet'), findsOneWidget);
    await tester.runAsync(
      () => File('${root.path}/New movie.mp4').writeAsString('fixture'),
    );
    await tester.tap(find.text('Refresh'));
    await loaded(tester);
    expect(find.text('New movie.mp4'), findsOneWidget);
  });

  testWidgets(
    'missing folder retries after creation without leaking an absolute path',
    (tester) async {
      final base = await fixture(tester);
      final root = Directory('${base.path}/missing');
      await tester.pumpWidget(page(root));
      await loaded(tester);
      expect(
        find.textContaining('This folder could not be read'),
        findsOneWidget,
      );
      expect(find.textContaining(root.path), findsNothing);
      await tester.runAsync(() async {
        await root.create();
        await File('${root.path}/Available.mp4').writeAsString('fixture');
      });
      await tester.tap(find.text('Retry'));
      await loaded(tester);
      expect(find.text('Available.mp4'), findsOneWidget);
    },
  );

  testWidgets(
    'unreadable folder recovers after permissions are restored',
    (tester) async {
      final root = await fixture(tester);
      await tester.runAsync(() async {
        await File('${root.path}/Available.mp4').writeAsString('fixture');
        expect((await Process.run('chmod', ['000', root.path])).exitCode, 0);
      });
      addTearDown(() async {
        await Process.run('chmod', ['700', root.path]);
      });
      await tester.pumpWidget(page(root));
      await loaded(tester);
      expect(
        find.textContaining('This folder could not be read'),
        findsOneWidget,
      );
      await tester.runAsync(() => Process.run('chmod', ['700', root.path]));
      await tester.tap(find.text('Retry'));
      await loaded(tester);
      expect(find.text('Available.mp4'), findsOneWidget);
    },
    skip: !Platform.isLinux,
  );

  testWidgets(
    'Up from a folder far down the list scrolls back to it and focuses it',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final root = await fixture(tester);
      await tester.runAsync(() async {
        for (var i = 0; i < 80; i++) {
          await Directory(
            '${root.path}/Folder ${i.toString().padLeft(3, '0')}',
          ).create();
        }
        await File(
          '${root.path}/Folder 070/Inside.mp4',
        ).writeAsString('fixture');
      });
      await tester.pumpWidget(page(root));
      await loaded(tester);
      await tester.scrollUntilVisible(find.text('Folder 070'), 300);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Folder 070'));
      await loaded(tester);
      expect(find.text('Inside.mp4'), findsOneWidget);
      await tester.tap(find.text('Up'));
      await loaded(tester);
      await tester.pump();
      expect(find.text('Folder 070'), findsOneWidget);
      expect(
        (FocusManager.instance.primaryFocus?.context
                    ?.findAncestorWidgetOfExactType<ListTile>()
                    ?.title
                as Text?)
            ?.data,
        'Folder 070',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('a removed file is not played; a file linked from elsewhere is', (
    tester,
  ) async {
    final root = await fixture(tester);
    final movie = File('${root.path}/Gone.mp4');
    await tester.runAsync(() => movie.writeAsString('fixture'));
    var plays = 0;
    await tester.pumpWidget(
      page(
        root,
        onPlay: (_, _, _) async {
          plays++;
        },
      ),
    );
    await loaded(tester);
    await tester.runAsync(movie.delete);
    await tester.tap(find.text('Gone.mp4'));
    await settle(tester);
    expect(plays, 0);
    expect(
      find.textContaining('Could not open this media file'),
      findsOneWidget,
    );
    await tester.runAsync(() async {
      final outside = File(
        '${root.parent.path}/${root.uri.pathSegments.where((s) => s.isNotEmpty).last}-outside.mp4',
      );
      await outside.writeAsString('fixture');
      addTearDown(outside.delete);
      await Link(movie.path).create(outside.path);
    });
    await tester.tap(find.text('Gone.mp4'));
    await settle(tester);
    expect(plays, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a folder linked from elsewhere opens and Up returns to Videos', (
    tester,
  ) async {
    final root = await fixture(tester);
    final outside = await fixture(tester);
    final folder = Directory('${root.path}/Folder');
    await tester.runAsync(() async {
      await folder.create();
      await File('${outside.path}/Outside.mp4').writeAsString('fixture');
    });
    await tester.pumpWidget(page(root));
    await loaded(tester);
    await tester.runAsync(() async {
      await folder.delete();
      await Link(folder.path).create(outside.path);
    });
    await tester.tap(find.text('Folder'));
    await loaded(tester);
    expect(find.text('Outside.mp4'), findsOneWidget);
    expect(find.text('/Folder'), findsOneWidget);
    await tester.tap(find.text('Up'));
    await loaded(tester);
    expect(find.text('Folder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('playback launch is serialized and failure allows retry', (
    tester,
  ) async {
    final root = await fixture(tester);
    await tester.runAsync(() async {
      for (final name in ['One.mp4', 'Two.mp4']) {
        await File('${root.path}/$name').writeAsString('fixture');
      }
    });
    final launches = <String>[];
    var hold = Completer<void>();
    await tester.pumpWidget(
      page(
        root,
        onPlay: (_, channel, siblings) async {
          launches.add(channel.name);
          expect(siblings.map((c) => c.name), ['One.mp4', 'Two.mp4']);
          await hold.future;
        },
      ),
    );
    await loaded(tester);
    await tester.tap(find.text('One.mp4'));
    await settle(tester);
    await tester.tap(find.text('Two.mp4'));
    await settle(tester);
    expect(launches, ['One.mp4']);
    hold.completeError(StateError('player failed'));
    await settle(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('An error occurred'), findsOneWidget);
    expect(find.textContaining('Could not open this media file'), findsNothing);
    hold = Completer<void>()..complete();
    await tester.tap(find.text('Two.mp4'));
    await settle(tester);
    expect(launches, ['One.mp4', 'Two.mp4']);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('unreadable media is rejected before player launch', (
    tester,
  ) async {
    final root = await fixture(tester);
    final movie = File('${root.path}/Locked.mp4');
    await tester.runAsync(() async {
      await movie.writeAsString('fixture');
      await Process.run('chmod', ['000', movie.path]);
    });
    addTearDown(() => Process.runSync('chmod', ['644', movie.path]));
    var plays = 0;
    await tester.pumpWidget(page(root, onPlay: (_, _, _) async => plays++));
    await loaded(tester);
    await tester.tap(find.text('Locked.mp4'));
    await settle(tester);
    expect(plays, 0);
    expect(
      find.textContaining('Could not open this media file'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('old scan cannot replace a newer root or update disposed state', (
    tester,
  ) async {
    final root = await fixture(tester);
    final replacement = await fixture(tester);
    await tester.runAsync(
      () => File('${replacement.path}/New root.mp4').writeAsString('fixture'),
    );
    final release = Completer<void>();
    await tester.pumpWidget(page(HeldDirectory(root, release)));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpWidget(page(replacement));
    await loaded(tester);
    expect(find.text('New root.mp4'), findsOneWidget);
    release.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(find.text('New root.mp4'), findsOneWidget);
    final disposedRelease = Completer<void>();
    await tester.pumpWidget(page(HeldDirectory(root, disposedRelease)));
    await tester.pumpWidget(const SizedBox());
    disposedRelease.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('large folders render lazily and long names fit a narrow window', (
    tester,
  ) async {
    final root = await fixture(tester);
    await tester.runAsync(() async {
      await Future.wait([
        for (var i = 0; i < 600; i++)
          File(
            '${root.path}/${i.toString().padLeft(3, '0')}${'Long name ' * 10}.mp4',
          ).writeAsString('fixture'),
      ]);
    });
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) => MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: child!,
        ),
        home: LocalMediaPage(rootDirectory: root),
      ),
    );
    await loaded(tester);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    expect(find.byType(ListTile), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
