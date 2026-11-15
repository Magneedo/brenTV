import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/library/download_queue.dart';
import 'package:brentv/library/models.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> until(bool Function() done) async {
  for (var i = 0; i < 500 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  expect(done(), true, reason: 'download did not settle');
}

void main() {
  late Directory root;
  late HttpServer server;
  late List<String?> ranges;
  late Future<void> Function(HttpRequest) respond;
  late DownloadQueue queue;
  final bytes = List<int>.generate(256 * 1024, (i) => i % 251);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('brentv-download-test-');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ranges = [];
    respond = (request) async {
      final range = request.headers.value('range');
      ranges.add(range);
      final offset = range == null
          ? 0
          : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
      request.response.headers.set('etag', '"video-v1"');
      request.response.headers.contentType = ContentType('video', 'mp4');
      if (range != null) {
        expect(request.headers.value('if-range'), '"video-v1"');
        request.response.statusCode = 206;
        request.response.headers.set(
          'content-range',
          'bytes $offset-${bytes.length - 1}/${bytes.length}',
        );
      }
      request.response.contentLength = bytes.length - offset;
      request.response.add(bytes.sublist(offset));
      await request.response.close();
    };
    server.listen((request) {
      unawaited(() async {
        try {
          await respond(request);
        } on SocketException {
          /* A paused client disconnected. */
        } on HttpException {
          /* A paused client disconnected. */
        }
      }());
    });
    queue = DownloadQueue(
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
      canStart: (_, extra) => true,
      freeSpace: (_) async => 1024 * 1024 * 1024,
    );
  });
  tearDown(() async {
    await queue.shutdown();
    queue.dispose();
    await server.close(force: true);
    await root.delete(recursive: true);
  });
  DownloadJob job() => DownloadJob(
    id: 'a',
    title: 'Movie',
    identity: 'catalog',
    file: '${root.path}/Movie.mp4',
    channelId: 1,
    sourceId: 1,
  );
  test(
    'concurrent additions reserve each video and output file once',
    () async {
      queue = DownloadQueue(
        resolve: queue.resolve,
        save: (_) async {},
        preferences: () => MediaPreferences(),
        canStart: (_, _) => false,
      );
      for (final sameVideo in [true, false]) {
        final a = job();
        final b = DownloadJob(
          id: 'b',
          title: 'Second',
          identity: 'catalog',
          file: sameVideo ? '${root.path}/Second.mp4' : a.file,
          channelId: sameVideo ? a.channelId : 2,
          sourceId: 1,
        );
        var rejected = 0;
        await Future.wait([
          for (final candidate in [a, b])
            queue.add(candidate).catchError((Object error) {
              expect(error, isA<DownloadFailure>());
              rejected++;
            }),
        ]);
        expect(rejected, 1);
        expect(queue.jobs, hasLength(1));
        queue.jobs.clear();
      }
    },
  );
  test(
    'resumes persisted partial bytes and atomically finishes exact server contents',
    () async {
      final j = job()
        ..etag = '"video-v1"'
        ..total = bytes.length
        ..state = DownloadState.downloading;
      await File(j.part).writeAsBytes(bytes.sublist(0, 10000));
      await queue.initialize(jsonEncode([j.toJson()]));
      await until(() => queue.jobs.single.state == DownloadState.completed);
      expect(ranges, ['bytes=10000-']);
      expect(await File(j.file).readAsBytes(), bytes);
      expect(await File(j.part).exists(), false);
    },
  );
  test(
    'a server without validators resumes by size and restarts when it changed',
    () async {
      final total = bytes.length;
      respond = (request) async {
        final range = request.headers.value('range');
        ranges.add(range);
        expect(request.headers.value('if-range'), isNull);
        final offset = range == null
            ? 0
            : int.parse(RegExp(r'bytes=(\d+)-').firstMatch(range)![1]!);
        request.response.headers.contentType = ContentType('video', 'mp4');
        if (range != null) {
          request.response.statusCode = 206;
          request.response.headers.set(
            'content-range',
            'bytes $offset-${bytes.length - 1}/$total',
          );
        }
        request.response.contentLength = bytes.length - offset;
        request.response.add(bytes.sublist(offset));
        await request.response.close();
      };
      final j = job()
        ..total = bytes.length
        ..state = DownloadState.downloading;
      await File(j.part).writeAsBytes(bytes.sublist(0, 10000));
      await queue.initialize(jsonEncode([j.toJson()]));
      await until(() => queue.jobs.single.state == DownloadState.completed);
      expect(ranges, ['bytes=10000-']);
      expect(await File(j.file).readAsBytes(), bytes);

      // A different total means a different file: never append to it.
      await File(j.file).delete();
      await queue.cancel(queue.jobs.single);
      ranges.clear();
      final changed = job()..total = bytes.length - 1;
      await File(changed.part).writeAsBytes(List.filled(10000, 7));
      queue.jobs.add(changed);
      await queue.pump();
      await until(() => changed.state == DownloadState.completed);
      expect(ranges, ['bytes=10000-', null]);
      expect(await File(changed.file).readAsBytes(), bytes);
    },
  );
  test(
    'server ignoring Range replaces the partial file instead of appending',
    () async {
      respond = (request) async {
        ranges.add(request.headers.value('range'));
        request.response.headers.set('etag', '"video-v2"');
        request.response.contentLength = bytes.length;
        request.response.add(bytes);
        await request.response.close();
      };
      final j = job()
        ..etag = '"video-v1"'
        ..total = bytes.length;
      await File(j.part).writeAsBytes(List.filled(10000, 255));
      await queue.initialize(jsonEncode([j.toJson()]));
      await until(() => queue.jobs.single.state == DownloadState.completed);
      expect(await File(j.file).readAsBytes(), bytes);
      expect(ranges.single, 'bytes=10000-');
    },
  );
  test('changed validator on a partial response restarts safely', () async {
    final normal = respond;
    respond = (request) async {
      if (ranges.isEmpty) {
        ranges.add(request.headers.value('range'));
        request.response.statusCode = 206;
        request.response.headers.set('etag', '"changed"');
        request.response.headers.set(
          'content-range',
          'bytes 10000-${bytes.length - 1}/${bytes.length}',
        );
        request.response.contentLength = bytes.length - 10000;
        request.response.add(bytes.sublist(10000));
        await request.response.close();
      } else {
        await normal(request);
      }
    };
    final j = job()
      ..etag = '"video-v1"'
      ..total = bytes.length;
    await File(j.part).writeAsBytes(List.filled(10000, 255));
    await queue.initialize(jsonEncode([j.toJson()]));
    await until(() => queue.jobs.single.state == DownloadState.completed);
    expect(ranges, ['bytes=10000-', null]);
    expect(await File(j.file).readAsBytes(), bytes);
  });
  test('invalid range never appends to a partial file', () async {
    respond = (request) async {
      request.response.statusCode = 206;
      request.response.headers.set('content-range', 'bytes 3-8/9');
      request.response.add([1, 2, 3, 4, 5, 6]);
      await request.response.close();
    };
    final j = job()
      ..etag = '"video-v1"'
      ..total = bytes.length;
    await File(j.part).writeAsBytes(bytes.sublist(0, 10000));
    await queue.initialize(jsonEncode([j.toJson()]));
    await until(() => queue.jobs.single.state == DownloadState.failed);
    expect(await File(j.part).length(), 10000);
    expect(await File(j.file).exists(), false);
    expect(queue.jobs.single.error, contains('invalid resume range'));
  });
  test('disk check prevents writes and shows a clear failure', () async {
    queue.dispose();
    queue = DownloadQueue(
      resolve: (id) async => pb.TransferInfo(
        identity: 'catalog',
        channel: pb.Channel(
          sourceId: Int64(1),
          url: 'http://127.0.0.1:${server.port}/video.mp4',
        ),
      ),
      save: (_) async {},
      preferences: () => MediaPreferences(),
      canStart: (_, extra) => true,
      freeSpace: (_) async => 1,
    );
    await queue.initialize('');
    await queue.add(job());
    await until(() => queue.jobs.single.state == DownloadState.failed);
    expect(queue.jobs.single.error, contains('Not enough free disk space'));
    expect(await File(queue.jobs.single.part).exists(), false);
  });
  test('movie and season filenames use separate user folders', () {
    final p = MediaPreferences();
    expect(
      downloadFilename('Movie (2026)', 'https://example.test/movie.mkv', p),
      '${p.moviesFolder}/Movie (2026).mkv',
    );
    expect(
      downloadFilename(
        'Pilot',
        'https://example.test/episode.mp4',
        p,
        show: 'A Show',
        season: 1,
        episode: 2,
      ),
      '${p.seriesFolder}/A Show/Season 01/A Show - S01E02 - Pilot.mp4',
    );
    for (final title in [
      'A Show - S01E02 - Pilot',
      'a show S01 E02: Pilot',
      'S01E02 - Pilot',
    ]) {
      expect(
        downloadFilename(
          title,
          'x.mp4',
          p,
          show: 'A Show',
          season: 1,
          episode: 2,
        ),
        '${p.seriesFolder}/A Show/Season 01/A Show - S01E02 - Pilot.mp4',
      );
    }
    expect(
      downloadFilename(
        'A Show - S01E02',
        'x.mp4',
        p,
        show: 'A Show',
        season: 1,
        episode: 2,
      ),
      '${p.seriesFolder}/A Show/Season 01/A Show - S01E02.mp4',
    );
  });
  test(
    'pause flushes a partial file and Resume sends its exact next byte',
    () async {
      final normal = respond;
      respond = (request) async {
        if (request.headers.value('range') != null) {
          await normal(request);
          return;
        }
        ranges.add(null);
        request.response.headers.set('etag', '"video-v1"');
        request.response.contentLength = bytes.length;
        for (var i = 0; i < bytes.length; i += 8192) {
          request.response.add(bytes.sublist(i, i + 8192));
          await request.response.flush();
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        await request.response.close();
      };
      await queue.initialize('');
      final j = job();
      await queue.add(j);
      await until(() => j.bytes >= 32768);
      await queue.pause(j);
      final saved = await File(j.part).length();
      expect(j.state, DownloadState.paused);
      expect(saved, lessThan(bytes.length));
      await queue.resume(j);
      await until(() => j.state == DownloadState.completed);
      expect(ranges.last, 'bytes=$saved-');
      expect(await File(j.file).readAsBytes(), bytes);
    },
  );
  test(
    '416 finalizes only when saved validator and complete size match',
    () async {
      respond = (request) async {
        ranges.add(request.headers.value('range'));
        request.response.statusCode = 416;
        request.response.headers.set('etag', '"video-v1"');
        request.response.headers.set(
          'content-range',
          'bytes */${bytes.length}',
        );
        await request.response.close();
      };
      final j = job()
        ..total = bytes.length
        ..etag = '"video-v1"';
      await File(j.part).writeAsBytes(bytes);
      await queue.initialize(jsonEncode([j.toJson()]));
      await until(() => queue.jobs.single.state == DownloadState.completed);
      expect(ranges.single, 'bytes=${bytes.length}-');
      expect(await File(j.file).readAsBytes(), bytes);
    },
  );
  test('retryable HTTP errors wait for backoff instead of spinning', () async {
    respond = (request) async {
      ranges.add(request.headers.value('range'));
      request.response.statusCode = 503;
      await request.response.close();
    };
    await queue.initialize('');
    final j = job();
    await queue.add(j);
    await until(() => j.state == DownloadState.queued && j.attempts == 1);
    expect(j.retryAt, greaterThan(unixNow));
    await queue.pump();
    expect(ranges, hasLength(1));
    expect(j.error, isNot(contains('127.0.0.1')));
    await queue.pause(j);
  });
}
