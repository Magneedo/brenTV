import 'package:flutter_test/flutter_test.dart';
import 'package:brentv/models/settings.dart';
import 'package:brentv/playback/mpv/options.dart';

void main() {
  test('quoted and escaped extra arguments', () {
    expect(
      splitMpvArgs(' --title="hello world" \'two words\' empty="" a\\ b '),
      ['--title=hello world', 'two words', 'empty=', 'a b'],
    );
    expect(splitMpvArgs("''"), ['']);
    expect(() => splitMpvArgs("'unfinished"), throwsFormatException);
  });
  test('managed options preserve config and omit empty hwdec', () {
    final settings = Settings(
      hwdec: '',
      cacheSecs: 7,
      demuxerMaxMb: 42,
      lowLatency: true,
    );
    final args = mpvArguments(settings, '/private/ipc', live: true);
    expect(
      args,
      containsAll([
        '--idle=yes',
        '--cache-secs=7',
        '--demuxer-readahead-secs=7',
        '--demuxer-max-bytes=42MiB',
        '--profile=low-latency',
      ]),
    );
    expect(
      args.any(
        (a) =>
            a.startsWith('--hwdec') ||
            a == '--no-config' ||
            a.startsWith('--input-conf'),
      ),
      false,
    );
    settings.mpvReuseWindow = false;
    expect(mpvArguments(settings, 's', live: false), contains('--idle=once'));
    expect(
      mpvArguments(settings, 's', live: false),
      isNot(contains('--profile=low-latency')),
    );
  });
  test('keys only override the requested bindings', () {
    expect(mpvKeyBindings, hasLength(18));
    expect(mpvKeyBindings['A'], 'brentv-feed-prev');
    expect(mpvKeyBindings['BS'], 'brentv-last');
    expect(mpvKeyBindings['F1'], 'brentv-favorite-1');
    expect(mpvKeyBindings['F9'], 'brentv-favorite-9');
    expect(mpvKeyBindings.containsKey('0'), isFalse);
    expect(mpvKeyBindings.containsKey('q'), isFalse);
  });
}
