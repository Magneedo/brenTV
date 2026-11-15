import 'dart:convert';
import 'dart:io';

Map<String, dynamic> jsonObject(String value) {
  if (value.isEmpty) return {};
  return Map<String, dynamic>.from(jsonDecode(value) as Map);
}

String safeFilename(String value) {
  final cleaned = value
      .replaceAll(RegExp(r'[\x00-\x1f\x7f/\\:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'^[. ]+|[. ]+$'), '');
  final buffer = StringBuffer();
  var size = 0;
  for (final rune in cleaned.runes) {
    final character = String.fromCharCode(rune);
    size += utf8.encode(character).length;
    if (size > 100) break;
    buffer.write(character);
  }
  final limited = buffer.toString();
  return limited.isEmpty ? 'Untitled' : limited;
}

String two(int n) => n.toString().padLeft(2, '0');
String recordingFilename(String channel, String programme, DateTime start) =>
    '${safeFilename(channel)} - ${safeFilename(programme)} - ${start.year}-${two(start.month)}-${two(start.day)} ${two(start.hour)}${two(start.minute)}';
int get unixNow => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class MediaPreferences {
  String recordingFolder;
  String moviesFolder, seriesFolder;
  int concurrentDownloads;

  /// Streams the provider really allows at once; 0 trusts what it reports.
  int connectionLimit;
  int paddingBefore, paddingAfter;

  /// iPhone: repackage every live channel, not only those that need it.
  bool relayAlways;

  /// iPhone: live channels that failed in Apple's player as provided and are
  /// opened through the repackager straight away. Newest last.
  final List<int> relayChannels;
  final Set<String> dismissedTips;
  final Set<String> usedFeatures;
  MediaPreferences({
    String? recordingFolder,
    String? moviesFolder,
    String? seriesFolder,
    this.concurrentDownloads = 1,
    this.connectionLimit = 0,
    this.paddingBefore = 2,
    this.paddingAfter = 5,
    this.relayAlways = false,
    List<int>? relayChannels,
    Set<String>? dismissedTips,
    Set<String>? usedFeatures,
  }) : recordingFolder =
           recordingFolder ??
           '${Platform.environment['HOME'] ?? ''}/Videos/DVR',
       moviesFolder =
           moviesFolder ??
           '${Platform.environment['HOME'] ?? ''}/Videos/Movies',
       seriesFolder =
           seriesFolder ??
           '${Platform.environment['HOME'] ?? ''}/Videos/Series',
       relayChannels = relayChannels ?? [],
       dismissedTips = dismissedTips ?? {},
       usedFeatures = usedFeatures ?? {};
  factory MediaPreferences.decode(String value) {
    final m = jsonObject(value);
    return MediaPreferences(
      recordingFolder: m['recordingFolder'] as String?,
      moviesFolder: m['moviesFolder'] as String?,
      seriesFolder: m['seriesFolder'] as String?,
      concurrentDownloads: (m['concurrentDownloads'] as int? ?? 1).clamp(1, 4),
      connectionLimit: (m['connectionLimit'] as int? ?? 0).clamp(0, 8),
      paddingBefore: (m['paddingBefore'] as int? ?? 2).clamp(0, 60),
      paddingAfter: (m['paddingAfter'] as int? ?? 5).clamp(0, 120),
      relayAlways: m['relayAlways'] == true,
      relayChannels: List<int>.from(
        (m['relayChannels'] as List? ?? []).whereType<int>(),
      ),
      dismissedTips: Set<String>.from(m['dismissedTips'] ?? []),
      usedFeatures: Set<String>.from(m['usedFeatures'] ?? []),
    );
  }
  String encode() => jsonEncode({
    'recordingFolder': recordingFolder,
    'moviesFolder': moviesFolder,
    'seriesFolder': seriesFolder,
    'concurrentDownloads': concurrentDownloads,
    'connectionLimit': connectionLimit,
    'paddingBefore': paddingBefore,
    'paddingAfter': paddingAfter,
    'relayAlways': relayAlways,
    'relayChannels': relayChannels,
    'dismissedTips': dismissedTips.toList(),
    'usedFeatures': usedFeatures.toList(),
  });
}

enum RecordingState {
  scheduled,
  recording,
  finishing,
  completed,
  missed,
  failed,
  canceled,
}

class RecordingJob {
  final String id, channelName, title, identity;
  final int channelId, sourceId, start, stop, maxConnections;
  RecordingState state;

  /// Saved by the player from the stream it is showing, so it needs no
  /// provider connection of its own.
  bool viaPlayer;
  String? file, error;
  int? actualStart;
  RecordingJob({
    required this.id,
    required this.channelId,
    required this.sourceId,
    required this.channelName,
    required this.title,
    required this.identity,
    required this.start,
    required this.stop,
    required this.maxConnections,
    this.state = RecordingState.scheduled,
    this.viaPlayer = false,
    this.file,
    this.error,
    this.actualStart,
  });
  bool get active =>
      state == RecordingState.recording || state == RecordingState.finishing;
  bool get reserved => active || state == RecordingState.scheduled;
  static (int, int) padded(int start, int stop, int before, int after) =>
      (start - before * 60, stop + after * 60);

  /// A recording whose start was missed while the app was closed is never
  /// silently turned into a partial recording, even if its end is still future.
  void recover(int now) {
    if (active) {
      state = RecordingState.failed;
      error = 'Interrupted when the app closed; any partial file is retained.';
    } else if (state == RecordingState.scheduled && start < now) {
      state = RecordingState.missed;
      error = 'The app was closed at the scheduled start.';
    }
  }

  List<RecordingJob> conflicts(Iterable<RecordingJob> jobs) {
    final overlapping = jobs
        .where(
          (j) =>
              j.id != id &&
              j.sourceId == sourceId &&
              j.reserved &&
              // A player segment being remuxed no longer captures a stream.
              !(j.viaPlayer && j.state == RecordingState.finishing) &&
              j.start < stop &&
              start < j.stop,
        )
        .toList();
    final points = <(int, int)>[(start, 1), (stop, -1)];
    for (final j in overlapping) {
      points.add((j.start < start ? start : j.start, 1));
      points.add((j.stop > stop ? stop : j.stop, -1));
    }
    points.sort(
      (a, b) => a.$1 == b.$1 ? a.$2.compareTo(b.$2) : a.$1.compareTo(b.$1),
    );
    var count = 0;
    for (final p in points) {
      count += p.$2;
      if (count > maxConnections) return overlapping;
    }
    return [];
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channelId': channelId,
    'sourceId': sourceId,
    'channelName': channelName,
    'title': title,
    'identity': identity,
    'start': start,
    'stop': stop,
    'maxConnections': maxConnections,
    'state': state.name,
    'viaPlayer': viaPlayer,
    'file': file,
    'error': error,
    'actualStart': actualStart,
  };
  factory RecordingJob.fromJson(Map<String, dynamic> m) => RecordingJob(
    id: m['id'],
    channelId: m['channelId'],
    sourceId: m['sourceId'],
    channelName: m['channelName'],
    title: m['title'],
    identity: m['identity'],
    start: m['start'],
    stop: m['stop'],
    maxConnections: m['maxConnections'],
    state: RecordingState.values.byName(m['state']),
    viaPlayer: m['viaPlayer'] ?? false,
    file: m['file'],
    error: m['error'],
    actualStart: m['actualStart'],
  );
}

enum DownloadState {
  queued,
  downloading,
  paused,
  completed,
  failed,
  canceled,
  converting,
}

class DownloadJob {
  final String id, title, identity;
  String file;
  bool readyToConvert;
  String? conversionSource, conversionTarget;
  bool conversionSourceIsPartial;
  double? conversionProgress;
  final int channelId, sourceId;
  DownloadState state;
  int bytes, total, attempts, retryAt;
  double speed = 0;
  String? etag, lastModified, error;
  DownloadJob({
    required this.id,
    required this.title,
    required this.identity,
    required this.file,
    required this.channelId,
    required this.sourceId,
    this.readyToConvert = false,
    this.conversionSource,
    this.conversionTarget,
    this.conversionSourceIsPartial = false,
    this.state = DownloadState.queued,
    this.bytes = 0,
    this.total = 0,
    this.attempts = 0,
    this.retryAt = 0,
    this.etag,
    this.lastModified,
    this.error,
  });
  String get part => '$file.part';
  String get conversionDestination => conversionTarget ?? file;
  String? get offlineFile => state == DownloadState.completed
      ? file
      : (conversionSource != null && !conversionSourceIsPartial
            ? conversionSource
            : null);
  int? get eta =>
      total > bytes && speed > 0 ? ((total - bytes) / speed).ceil() : null;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'identity': identity,
    'file': file,
    'channelId': channelId,
    'sourceId': sourceId,
    'readyToConvert': readyToConvert,
    'conversionSource': conversionSource,
    'conversionTarget': conversionTarget,
    'conversionSourceIsPartial': conversionSourceIsPartial,
    'state': state.name,
    'bytes': bytes,
    'total': total,
    'attempts': attempts,
    'retryAt': retryAt,
    'etag': etag,
    'lastModified': lastModified,
    'error': error,
  };
  factory DownloadJob.fromJson(Map<String, dynamic> m) => DownloadJob(
    id: m['id'],
    title: m['title'],
    identity: m['identity'],
    file: m['file'],
    channelId: m['channelId'],
    sourceId: m['sourceId'],
    readyToConvert: m['readyToConvert'] ?? false,
    conversionSource: m['conversionSource'],
    conversionTarget: m['conversionTarget'],
    conversionSourceIsPartial: m['conversionSourceIsPartial'] ?? false,
    state: DownloadState.values.byName(m['state']),
    bytes: m['bytes'] ?? 0,
    total: m['total'] ?? 0,
    attempts: m['attempts'] ?? 0,
    retryAt: m['retryAt'] ?? 0,
    etag: m['etag'],
    lastModified: m['lastModified'],
    error: m['error'],
  );
}

String downloadFilename(
  String title,
  String url,
  MediaPreferences preferences, {
  String show = '',
  int season = 0,
  int episode = 0,
  bool mp4 = false,
}) {
  final path = Uri.parse(url).path;
  final suffix = path.split('.').last.toLowerCase();
  const extensions = {
    'mkv',
    'mp4',
    'm4v',
    'avi',
    'mov',
    'webm',
    'ts',
    'mpeg',
    'mpg',
  };
  final extension = mp4
      ? 'mp4'
      : (extensions.contains(suffix) ? suffix : 'mp4');
  if (show.isEmpty) {
    return '${preferences.moviesFolder}/${safeFilename(title)}.$extension';
  }
  // Providers often name an episode "Show - S01E02 - Title" already.
  var name = title.trim();
  if (name.toLowerCase().startsWith(show.toLowerCase())) {
    name = name.substring(show.length);
  }
  name = name
      .replaceFirst(
        RegExp(r'^[\s\-–—:|.]*S\d{1,3}\s*E\d{1,4}', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'^[\s\-–—:|.]+'), '');
  final prefix =
      '${preferences.seriesFolder}/${safeFilename(show)}/Season ${two(season)}/${safeFilename(show)} - S${two(season)}E${two(episode)}';
  return name.isEmpty
      ? '$prefix.$extension'
      : '$prefix - ${safeFilename(name)}.$extension';
}
