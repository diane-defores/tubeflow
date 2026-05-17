import 'package:flutter/material.dart';

class PlaybackControlsPanel extends StatelessWidget {
  const PlaybackControlsPanel({
    super.key,
    required this.currentSeconds,
    required this.maxSeconds,
    required this.isPlaying,
    required this.onChanged,
    required this.onSeekEnd,
    required this.onBackTen,
    required this.onTogglePlayPause,
    required this.onForwardTen,
    required this.formatTime,
  });

  final double currentSeconds;
  final double maxSeconds;
  final bool isPlaying;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onSeekEnd;
  final VoidCallback onBackTen;
  final VoidCallback onTogglePlayPause;
  final VoidCallback onForwardTen;
  final String Function(double seconds) formatTime;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Slider(
            value: currentSeconds,
            max: maxSeconds,
            onChanged: onChanged,
            onChangeEnd: onSeekEnd,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(formatTime(currentSeconds)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.replay_10),
                    onPressed: onBackTen,
                  ),
                  IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: onTogglePlayPause,
                  ),
                  IconButton(
                    icon: const Icon(Icons.forward_10),
                    onPressed: onForwardTen,
                  ),
                ],
              ),
              Text(formatTime(maxSeconds)),
            ],
          ),
        ],
      ),
    );
  }
}
