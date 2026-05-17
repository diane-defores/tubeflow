import 'package:flutter/material.dart';

import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/utils/color_utils.dart';
import 'package:replayglowz_app/utils/date_utils.dart';
import 'package:replayglowz_app/widgets/media/media_thumbnail.dart';

class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    this.trailing,
  });

  final YouTubePlaylist playlist;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final color = playlist.color != null
        ? parseHexColor(playlist.color!)
        : Theme.of(context).colorScheme.primary;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              height: 90,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: color.withValues(alpha: 0.2)),
                  MediaThumbnail(
                    imageUrl: playlist.effectiveThumbnailUrl,
                    width: 120,
                    height: 90,
                    icon: Icons.playlist_play,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 4, color: color),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      playlist.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${playlist.videoCount} video${playlist.videoCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      playlist.cachedAt > 0
                          ? 'Updated ${formatDate(playlist.cachedAt)}'
                          : '',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
