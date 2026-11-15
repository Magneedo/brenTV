import 'dart:convert';
import 'dart:io';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/library/download_queue.dart';
import 'package:brentv/library/media_library.dart';
import 'package:brentv/library/models.dart';
import 'package:brentv/models/bottom_bar.dart';
import 'package:brentv/models/view_type.dart';
import 'package:brentv/native_bridge.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'expansion_test.dart' as fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'Documents folders and paused downloads follow the current app container',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'brentv-documents-rebase-',
      );
      final preferences = MediaPreferences()
        ..moviesFolder = '/private/old/Documents/Movies'
        ..seriesFolder = '/private/old/Documents/Series';
      final state = pb.Settings(
        mediaPreferences: preferences.encode(),
        downloadJobs: jsonEncode([
          DownloadJob(
            id: 'paused',
            title: 'Movie',
            identity: 'fixture',
            file: '/private/old/Documents/Movies/Movie.mp4',
            channelId: 1,
            sourceId: 1,
            state: DownloadState.paused,
            bytes: 12,
          ).toJson(),
          DownloadJob(
            id: 'loose',
            title: 'Loose',
            identity: 'local',
            file: '/private/old/Documents/Loose.mkv',
            channelId: 0,
            sourceId: 0,
            state: DownloadState.paused,
            readyToConvert: true,
            conversionSource: '/private/old/Documents/Loose.mkv',
            conversionTarget: '/private/old/Documents/Loose.mp4',
          ).toJson(),
        ]),
      );
      try {
        for (final container in ['first', 'updated']) {
          final documents = '${root.path}/$container/Documents';
          final library = MediaLibrary(
            resolve: (_) async => pb.TransferInfo(),
            save: (patch) async => state.mergeFromMessage(patch),
          );
          try {
            await library.initialize(state, documentsDirectory: documents);
            expect(library.storageError, isNull);
            expect(library.preferences.moviesFolder, '$documents/Movies');
            expect(library.preferences.seriesFolder, '$documents/Series');
            expect(await Directory('$documents/Movies').exists(), isTrue);
            expect(await Directory('$documents/Series').exists(), isTrue);
            expect(
              library.downloads.jobs.firstWhere((j) => j.id == 'paused').file,
              '$documents/Movies/Movie.mp4',
            );
            expect(
              library.downloads.jobs.firstWhere((j) => j.id == 'paused').part,
              '$documents/Movies/Movie.mp4.part',
            );
            expect(
              library.downloads.jobs.firstWhere((j) => j.id == 'paused').state,
              DownloadState.paused,
            );
            expect(
              library.downloads.jobs.firstWhere((j) => j.id == 'paused').bytes,
              12,
            );
            final loose = library.downloads.jobs.firstWhere(
              (j) => j.id == 'loose',
            );
            expect(loose.file, '$documents/Loose.mkv');
            expect(loose.conversionSource, '$documents/Loose.mkv');
            expect(loose.conversionTarget, '$documents/Loose.mp4');
            expect(
              MediaPreferences.decode(state.mediaPreferences).moviesFolder,
              '$documents/Movies',
            );
            expect(
              (jsonDecode(state.downloadJobs) as List).firstWhere(
                (j) => j['id'] == 'paused',
              )['file'],
              '$documents/Movies/Movie.mp4',
            );
          } finally {
            library.dispose();
          }
        }
      } finally {
        await root.delete(recursive: true);
      }
    },
  );
  test(
    'native persistence migrates tabs, serializes auto-enable, retains user hiding and recovers jobs',
    () async {
      final f = fixture.Fixture();
      await f.init(count: 2);
      final library = MediaLibrary();
      try {
        final bridge = NativeBridge.instance;
        final migrated = await bridge.getSettings();
        expect(migrated.bottomBar.visiblePages(), [
          ViewType.all,
          ViewType.categories,
          ViewType.favorites,
          ViewType.history,
          ViewType.downloads,
          ViewType.settings,
        ]);
        await fixture.sql(
          "UPDATE channels SET url='http://127.0.0.1:${f.server.port}/live/fixture.ts' WHERE id=1",
        );
        final data = await bridge.getTransferInfo(1);
        expect(data.channel.id.toInt(), 1);
        expect(data.maxConnections, 1);
        expect(data.identity, isNotEmpty);
        final old = RecordingJob(
          id: 'missed',
          channelId: 1,
          sourceId: 1,
          channelName: 'Fixture',
          title: 'Earlier',
          identity: data.identity,
          start: unixNow - 60,
          stop: unixNow + 60,
          maxConnections: 1,
        );
        await bridge.saveMediaState(
          pb.Settings(recordingJobs: jsonEncode([old.toJson()])),
        );
        await library.initialize(await bridge.getMediaState());
        expect(library.recordings.single.state, RecordingState.missed);
        expect(
          await Future.wait([
            library.firstUse(ViewType.recordings),
            library.firstUse(ViewType.downloads),
          ]),
          [true, false], // Media is already visible after migration.
        );
        final settings = await bridge.getSettings();
        expect(
          settings.bottomBar.visiblePages(),
          containsAll([ViewType.recordings, ViewType.downloads]),
        );
        expect(settings.bottomBar.pages.last.page, ViewType.settings);
        await bridge.setBottomBar(
          BottomBarConfig([
            for (final p in settings.bottomBar.pages)
              BottomBarPage(p.page, p.page != ViewType.recordings && p.visible),
          ]),
        );
        expect(await library.firstUse(ViewType.recordings), false);
        expect(
          (await bridge.getSettings()).bottomBar.visiblePages(),
          isNot(contains(ViewType.recordings)),
        );
        await bridge.updateSettings(
          migrated,
        ); // An older general settings copy cannot undo tab/job state.
        final saved = await bridge.getMediaState();
        expect(jsonDecode(saved.recordingJobs).single['state'], 'missed');
        expect(saved.recordingJobs, isNot(contains('http')));
        expect(
          (await bridge.getSettings()).bottomBar.visiblePages(),
          contains(ViewType.downloads),
        );
        expect(
          await bridge.getDiskSpace(Directory.systemTemp.path),
          greaterThan(0),
        );
        await coreDownload();
        f.requests.clear();
        await fixture.sql('UPDATE sources SET import_live=0');
        await expectLater(bridge.getTransferInfo(1), throwsException);
        expect(f.requests, isEmpty);
      } finally {
        await library.shutdown();
        library.dispose();
        await f.close();
        NativeBridge.instance.dispose();
        if (fixture.db != null) await fixture.db!.delete(recursive: true);
      }
    },
    skip: !fixture.native,
  );
}

/// The core's transfer engine behind the real queue: pause mid-file, resume
/// from the exact byte on a server without validators, finish atomically.
Future<void> coreDownload() async {
  final root = await Directory.systemTemp.createTemp('brentv-core-download-');
  final bytes = List<int>.generate(2 * 1024 * 1024, (i) => i % 251);
  final ranges = <String?>[];
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    final range = request.headers.value('range');
    ranges.add(range);
    final offset = range == null
        ? 0
        : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
    request.response.headers.contentType = ContentType('video', 'mp4');
    if (range != null) {
      request.response.statusCode = 206;
      request.response.headers.set(
        'content-range',
        'bytes $offset-${bytes.length - 1}/${bytes.length}',
      );
    }
    request.response.contentLength = bytes.length - offset;
    try {
      for (var i = offset; i < bytes.length; i += 32 * 1024) {
        request.response.add(
          bytes.sublist(i, (i + 32 * 1024).clamp(0, bytes.length)),
        );
        await request.response.flush();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await request.response.close();
    } catch (_) {
      /* The paused client disconnected. */
    }
  });
  final queue = DownloadQueue(
    resolve: (id) async => pb.TransferInfo(
      identity: 'catalog',
      maxConnections: 2,
      channel: pb.Channel(
        id: Int64(1),
        sourceId: Int64(1),
        url: 'http://127.0.0.1:${server.port}/video.mp4',
      ),
    ),
    save: (_) async {},
    preferences: () => MediaPreferences(),
    canStart: (_, _) => true,
    native: coreTransfer,
  );
  Future<void> until(bool Function() done) async {
    for (var i = 0; i < 1500 && !done(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(done(), true, reason: 'download did not settle');
  }

  try {
    await queue.initialize('');
    final job = DownloadJob(
      id: 'core',
      title: 'Movie',
      identity: 'catalog',
      file: '${root.path}/Movies/Movie.mp4',
      channelId: 1,
      sourceId: 1,
    );
    await queue.add(job);
    await until(() => File(job.part).existsSync() && job.bytes > 0);
    await queue.pause(job);
    final saved = await File(job.part).length();
    expect(job.state, DownloadState.paused);
    expect(saved, inExclusiveRange(0, bytes.length));
    expect(job.bytes, saved);
    expect(job.total, bytes.length);
    await queue.resume(job);
    await until(() => job.state == DownloadState.completed);
    expect(ranges, [null, 'bytes=$saved-']);
    expect(await File(job.file).readAsBytes(), bytes);
    expect(await File(job.part).exists(), false);
  } finally {
    await queue.shutdown();
    queue.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);
  }
}
