import 'package:flutter/material.dart';

class NoteGroupHeader extends StatelessWidget {
  const NoteGroupHeader({
    super.key,
    required this.title,
    required this.noteCount,
  });

  final String title;
  final int noteCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 28,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.play_arrow, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            '$noteCount note${noteCount == 1 ? '' : 's'}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
