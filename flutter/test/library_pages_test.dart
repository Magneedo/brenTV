import 'dart:io';
import 'package:brentv/library/media_page.dart';
import 'package:brentv/library/download_ui.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/models.dart';
import 'package:brentv/library/recording_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final library = MediaLibrary.instance;
  tearDown(() {
    library.downloads.jobs.clear();
    library.recordings.clear();
  });

  testWidgets('canceling a verified download requires confirmation', (
    tester,
  ) async {
    final root = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('brentv-verified-cancel-'),
    ))!;
    addTearDown(() => root.delete(recursive: true));
    final j = DownloadJob(
      id: 'verified',
      title: 'Verified movie',
      identity: 'same',
      file: '${root.path}/Movie.mp4',
      channelId: 1,
      sourceId: 1,
      state: DownloadState.paused,
      readyToConvert: true,
      bytes: 3,
      total: 3,
    );
    await tester.runAsync(() => File(j.part).writeAsBytes([1, 2, 3]));
    library.downloads.jobs.add(j);
    await tester.pumpWidget(
      const MaterialApp(home: DownloadsPage(activeOnly: true)),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm deletion'), findsOneWidget);
    expect(await tester.runAsync(() => File(j.part).readAsBytes()), [1, 2, 3]);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cancel'),
      ),
    );
    await tester.pumpAndSettle();
    expect(library.downloads.jobs, contains(j));
    expect(await tester.runAsync(() => File(j.part).readAsBytes()), [1, 2, 3]);
  });

  testWidgets('download indicator opens details and disappears when complete', (
    tester,
  ) async {
    var opened = 0;
    final job = DownloadJob(
      id: 'badge',
      title: 'Movie',
      identity: 'fixture',
      file: '/unused.mp4',
      channelId: 1,
      sourceId: 1,
      state: DownloadState.downloading,
      bytes: 50,
      total: 100,
    );
    library.downloads.jobs.add(job);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DownloadProgressIndicator(onOpen: () => opened++)),
      ),
    );
    expect(find.text('1 download · 50%'), findsOneWidget);
    await tester.tap(find.text('1 download · 50%'));
    expect(opened, 1);
    job.state = DownloadState.completed;
    library.downloads.notifyListeners();
    await tester.pump();
    expect(find.textContaining('download'), findsNothing);
  });

  testWidgets(
    'Media shows a completed download without a Transfers tab or manual refresh',
    (tester) async {
      final root = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('brentv-media-page-'),
      ))!;
      addTearDown(() => root.delete(recursive: true));
      final job = DownloadJob(
        id: 'new',
        title: 'New movie',
        identity: 'fixture',
        file: '${root.path}/New movie.mp4',
        channelId: 1,
        sourceId: 1,
        state: DownloadState.downloading,
      );
      library.downloads.jobs.add(job);
      await tester.pumpWidget(
        MaterialApp(home: MediaPage(rootDirectory: root)),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Transfers'), findsNothing);
      expect(find.text('New movie.mp4'), findsNothing);
      await tester.runAsync(() => File(job.file).writeAsBytes([1]));
      job.state = DownloadState.completed;
      library.downloads.notifyListeners();
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('New movie.mp4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('large Downloads list scrolls and retains position on updates', (
    tester,
  ) async {
    library.downloads.jobs.addAll([
      for (var i = 0; i < 200; i++)
        DownloadJob(
          id: '$i',
          title: 'Movie $i',
          identity: 'fixture',
          file: '/missing-brentv-test/Movie-$i.mp4',
          channelId: i,
          sourceId: 1,
          state: DownloadState.completed,
        ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: DownloadsPage()));
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Movie 199'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Movie 199'),
      700,
      maxScrolls: 100,
    );
    library.downloads.notifyListeners();
    await tester.pump();
    expect(find.text('Movie 199'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Play offline').last);
    final missing = find.text('This video has moved or been deleted.');
    // File.exists completes on the real IO loop, outside fake widget time.
    for (var i = 0; i < 100 && missing.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(missing, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('large DVR list reaches completed recordings after schedules', (
    tester,
  ) async {
    library.recordings.addAll([
      for (var i = 0; i < 200; i++)
        RecordingJob(
          id: '$i',
          channelId: i,
          sourceId: 1,
          channelName: 'Channel $i',
          title: 'Program $i',
          identity: 'fixture',
          start: 1000,
          stop: 2000,
          maxConnections: 1,
          state: i < 100 ? RecordingState.scheduled : RecordingState.completed,
        ),
    ]);
    await tester.pumpWidget(const MaterialApp(home: RecordingsPage()));
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.text('Channel 199 · Program 199'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Channel 199 · Program 199'),
      700,
      maxScrolls: 100,
    );
    library.changed();
    await tester.pump();
    expect(find.text('Channel 199 · Program 199'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
