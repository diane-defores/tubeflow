import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:replayglowz_app/providers/providers.dart';
import 'package:replayglowz_app/widgets/error_feedback.dart';

/// API quota and usage statistics screen.
///
/// Convex queries used:
/// - `metrics.getTodayQuotaUsage` — current YouTube API quota consumption
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(quotaUsageProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('API Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(quotaUsageProvider);
            },
          ),
        ],
      ),
      body: quotaAsync.when(
        data: (quotaData) {
          final usedQuota = (quotaData?['used'] as num?)?.toInt() ?? 0;
          final totalQuota = (quotaData?['limit'] as num?)?.toInt() ?? 10000;
          final recentCalls =
              (quotaData?['recentCalls'] as List<dynamic>?) ?? [];
          final dailyHistory =
              (quotaData?['dailyHistory'] as List<dynamic>?) ?? [];

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildQuotaCard(context, usedQuota, totalQuota),
              const SizedBox(height: 16),
              _buildDailySummaryCard(context, quotaData, dailyHistory),
              const SizedBox(height: 16),
              _buildRecentCallsSection(context, recentCalls),
            ],
          );
        },
        loading: () => _buildShimmerLoading(),
        error: (error, stack) => ErrorStateView(
          error: error,
          prefix: 'Failed to load stats',
          onRetry: () => ref.invalidate(quotaUsageProvider),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(child: Container(height: 100, color: Colors.white)),
          const SizedBox(height: 16),
          Card(child: Container(height: 200, color: Colors.white)),
          const SizedBox(height: 16),
          Card(child: Container(height: 300, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildQuotaCard(BuildContext context, int usedQuota, int totalQuota) {
    final percentage = totalQuota > 0 ? usedQuota / totalQuota : 0.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'YouTube API Quota',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$usedQuota / $totalQuota',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                minHeight: 12,
                backgroundColor: Colors.grey[200],
                color: percentage > 0.8
                    ? Colors.red
                    : percentage > 0.5
                    ? Colors.orange
                    : Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(percentage * 100).toStringAsFixed(1)}% used today - resets at midnight PT',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailySummaryCard(
    BuildContext context,
    Map<String, dynamic>? quotaData,
    List<dynamic> dailyHistory,
  ) {
    final syncs = (quotaData?['syncs'] as num?)?.toString() ?? '0';
    final videosFetched =
        (quotaData?['videosFetched'] as num?)?.toString() ?? '0';
    final playlistCount =
        (quotaData?['playlistCount'] as num?)?.toString() ?? '0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Today\'s Summary',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatTile(
                    context,
                    icon: Icons.sync,
                    label: 'Syncs',
                    value: syncs,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    context,
                    icon: Icons.video_library,
                    label: 'Videos Fetched',
                    value: videosFetched,
                  ),
                ),
                Expanded(
                  child: _buildStatTile(
                    context,
                    icon: Icons.playlist_play,
                    label: 'Playlists',
                    value: playlistCount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Last 7 Days', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 80,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (index) {
                  // Use real daily history if available, else fallback.
                  double heightFactor = 0.1;
                  if (index < dailyHistory.length) {
                    final dayUsed =
                        (dailyHistory[index] as num?)?.toDouble() ?? 0;
                    final maxUsed = dailyHistory.fold<double>(0, (a, b) {
                      final v = (b as num?)?.toDouble() ?? 0;
                      return v > a ? v : a;
                    });
                    heightFactor = maxUsed > 0
                        ? (dayUsed / maxUsed).clamp(0.05, 1.0)
                        : 0.1;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: heightFactor,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withValues(alpha: 0.6),
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][index],
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildRecentCallsSection(
    BuildContext context,
    List<dynamic> recentCalls,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent API Calls',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            // Table header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Endpoint',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Time',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'Cost',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            if (recentCalls.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No recent API calls',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ...recentCalls.take(20).map((call) {
                final callMap = call is Map<String, dynamic>
                    ? call
                    : <String, dynamic>{};
                final endpoint = callMap['endpoint'] as String? ?? 'unknown';
                final cost = (callMap['quotaUnits'] as num?)?.toInt() ?? 0;
                final timestamp = (callMap['timestamp'] as num?)?.toInt() ?? 0;

                // Calculate minutes ago.
                final minutesAgo = timestamp > 0
                    ? ((DateTime.now().millisecondsSinceEpoch - timestamp) /
                              60000)
                          .round()
                    : 0;
                final timeStr = minutesAgo < 60
                    ? '${minutesAgo}m ago'
                    : '${minutesAgo ~/ 60}h ago';

                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          endpoint,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          timeStr,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '$cost units',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: cost >= 100 ? Colors.red : null,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
