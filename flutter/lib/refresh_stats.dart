import 'package:flutter/material.dart';
import 'package:brentv/generated/generated_proto.pb.dart' as pb;
import 'package:brentv/models/source.dart';
import 'package:brentv/native_bridge.dart';
import 'package:brentv/error.dart';

const mediaLabels = ['Live', 'Movies', 'Series'];

String refreshSummary(pb.RefreshStats stats, {DateTime? now}) {
  final parts = <String>[
    for (final type in stats.types.where((t) => t.enabled))
      '${mediaLabels.elementAtOrNull(type.mediaType) ?? 'Other'} ${type.failed ? 'failed: ${type.error}' : type.imported}',
  ];
  final excluded = stats.types.fold<int>(0, (n, t) => n + t.excluded);
  if (excluded > 0) parts.add('$excluded excluded');
  if (!stats.success || stats.error.isNotEmpty) {
    parts.add(stats.error.isEmpty ? 'Refresh failed' : stats.error);
  }
  if (stats.finishedAt.toInt() > 0) {
    final age = (now ?? DateTime.now()).difference(
      DateTime.fromMillisecondsSinceEpoch(stats.finishedAt.toInt() * 1000),
    );
    parts.add(
      age.inMinutes < 1
          ? 'just now'
          : age.inHours < 1
          ? '${age.inMinutes} min ago'
          : age.inDays < 1
          ? '${age.inHours} hr ago'
          : '${age.inDays} days ago',
    );
  }
  return parts.join(' · ');
}

Future<void> showRefreshStats(
  BuildContext context,
  List<pb.RefreshStats> stats,
) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Refresh results'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stats.isEmpty) const Text('No enabled sources to refresh.'),
            for (final stat in stats) ...[
              Text(
                stat.sourceName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(refreshSummary(stat)),
              for (final type in stat.types.where((t) => t.enabled))
                Text(
                  '${mediaLabels.elementAtOrNull(type.mediaType) ?? 'Other'}: '
                  '${type.fetched} fetched, ${type.imported} imported, '
                  '${type.excluded} excluded, ${type.categories} categories'
                  '${type.failed ? '\nFailed (previous rows kept): ${type.error}' : ''}',
                ),
              Text('${stat.durationMs} ms'),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> offerRefresh(BuildContext context, Source source) async {
  if (!context.mounted) return;
  final refresh = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Refresh now?'),
      content: const Text('Refresh this source to apply the import filters.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Later'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Refresh now'),
        ),
      ],
    ),
  );
  if (refresh != true || !context.mounted) return;
  final result = await Error.tryAsyncNoLoading(
    () => NativeBridge.instance.refreshSource(source),
    context,
  );
  if (result.data != null && context.mounted) {
    await showRefreshStats(context, [result.data!]);
  }
}
