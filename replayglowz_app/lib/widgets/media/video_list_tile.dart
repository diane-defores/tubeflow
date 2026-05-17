import 'package:flutter/material.dart';

import 'package:replayglowz_app/models/models.dart';
import 'package:replayglowz_app/utils/duration_utils.dart';
import 'package:replayglowz_app/widgets/media/media_thumbnail.dart';

class VideoListTile extends StatelessWidget {
  const VideoListTile({
    super.key,
    required this.video,
    required this.onTap,
    this.leadingWidth = 120,
    this.leadingHeight = 68,
    this.trailing,
  });

  final YouTubeVideo video;
  final VoidCallback onTap;
  final double leadingWidth;
  final double leadingHeight;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final durationSec = parseDuration(video.duration);
    final subtitle = video.channelTitle.isEmpty
        ? (durationSec != null ? formatDuration(durationSec) : '')
        : '${video.channelTitle}'
              '${durationSec != null ? ' - ${formatDuration(durationSec)}' : ''}';

    return ListTile(
      leading: MediaThumbnail(
        imageUrl: video.thumbnailUrl,
        width: leadingWidth,
        height: leadingHeight,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
