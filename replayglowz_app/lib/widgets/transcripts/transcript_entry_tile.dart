import 'package:flutter/material.dart';

class TranscriptEntryTile extends StatelessWidget {
  const TranscriptEntryTile({
    super.key,
    required this.timestampLabel,
    required this.text,
    required this.onTap,
    this.speaker,
    this.isActive = false,
  });

  final String timestampLabel;
  final String text;
  final VoidCallback onTap;
  final String? speaker;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: isActive ? theme.colorScheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 58,
                child: Text(
                  timestampLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (speaker != null && speaker!.trim().isNotEmpty) ...[
                      Text(speaker!.trim(), style: theme.textTheme.labelSmall),
                      const SizedBox(height: 4),
                    ],
                    Text(text),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
