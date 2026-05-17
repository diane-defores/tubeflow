import 'package:flutter/material.dart';

import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/utils/color_utils.dart';
import 'package:replayglowz_app/utils/duration_utils.dart';
import 'package:replayglowz_app/widgets/media/media_thumbnail.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video, required this.onTap});

  final YouTubeVideo video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = parseDuration(video.duration);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MediaThumbnail(
              imageUrl: video.thumbnailUrl,
              height: 200,
              width: double.infinity,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: theme.textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          video.channelTitle,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      if (duration != null)
                        Text(
                          formatDuration(duration),
                          style: theme.textTheme.labelSmall,
                        ),
                    ],
                  ),
                  if (video.playlistTitle != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (video.playlistColor != null)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: parseHexColor(video.playlistColor!),
                              shape: BoxShape.circle,
                            ),
                          ),
                        Text(
                          video.playlistTitle!,
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
