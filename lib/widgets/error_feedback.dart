import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

bool _isFrench(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'fr';

String _copyLabel(BuildContext context) => _isFrench(context) ? 'Copier' : 'Copy';

String _retryLabel(BuildContext context) =>
    _isFrench(context) ? 'Réessayer' : 'Retry';

String formatErrorMessage(Object error, {String? prefix}) {
  final message = error.toString().trim();
  if (prefix == null || prefix.isEmpty) {
    return message;
  }
  return '$prefix: $message';
}

Future<void> copyErrorToClipboard(
  BuildContext context,
  Object error, {
  String? prefix,
}) async {
  final message = formatErrorMessage(error, prefix: prefix);
  await Clipboard.setData(ClipboardData(text: message));

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_isFrench(context) ? 'Erreur copiée' : 'Error copied'),
      duration: const Duration(seconds: 2),
    ),
  );
}

void showErrorSnackBar(
  BuildContext context, {
  required Object error,
  String? prefix,
}) {
  final message = formatErrorMessage(error, prefix: prefix);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: _copyLabel(context),
        onPressed: () {
          copyErrorToClipboard(context, error, prefix: prefix);
        },
      ),
    ),
  );
}

class InlineErrorCard extends StatelessWidget {
  const InlineErrorCard({
    super.key,
    required this.error,
    this.prefix,
  });

  final Object error;
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = formatErrorMessage(error, prefix: prefix);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            message,
            style: TextStyle(
              color: colorScheme.error,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => copyErrorToClipboard(
                context,
                error,
                prefix: prefix,
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: Text(_copyLabel(context)),
            ),
          ),
        ],
      ),
    );
  }
}

class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.error,
    this.prefix,
    this.onRetry,
    this.centered = true,
  });

  final Object error;
  final String? prefix;
  final VoidCallback? onRetry;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final message = formatErrorMessage(error, prefix: prefix);
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth.isFinite
            ? (constraints.maxWidth > 320.0 ? 320.0 : constraints.maxWidth)
            : 320.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: textWidth,
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => copyErrorToClipboard(
                      context,
                      error,
                      prefix: prefix,
                    ),
                    icon: const Icon(Icons.copy, size: 16),
                    label: Text(_copyLabel(context)),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(_retryLabel(context)),
              ),
            ],
          ],
        );
      },
    );

    if (!centered) {
      return content;
    }

    return Center(child: content);
  }
}
