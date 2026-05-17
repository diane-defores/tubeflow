import 'package:flutter/material.dart';

import 'package:replayglowz_app/widgets/app_states.dart';

class NoteTile extends StatelessWidget {
  const NoteTile({
    super.key,
    required this.content,
    this.timestampLabel,
    this.onTimestampTap,
    this.onTap,
    this.trailing,
    this.compactText = false,
  });

  final String content;
  final String? timestampLabel;
  final VoidCallback? onTimestampTap;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool compactText;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: timestampLabel == null
            ? null
            : AppTimestampBadge(text: timestampLabel!, onTap: onTimestampTap),
        title: Text(
          content,
          maxLines: compactText ? 2 : null,
          overflow: compactText ? TextOverflow.ellipsis : null,
          style: compactText ? Theme.of(context).textTheme.bodySmall : null,
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}
