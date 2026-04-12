import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  final isFr = Localizations.localeOf(context).languageCode == 'fr';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(isFr ? 'Erreur copiée' : 'Error copied'),
      duration: const Duration(seconds: 2),
    ),
  );
}

void showErrorSnackBar(
  BuildContext context, {
  required Object error,
  String? prefix,
}) {
  final isFr = Localizations.localeOf(context).languageCode == 'fr';
  final message = formatErrorMessage(error, prefix: prefix);

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      action: SnackBarAction(
        label: isFr ? 'Copier' : 'Copy',
        onPressed: () {
          copyErrorToClipboard(context, error, prefix: prefix);
        },
      ),
    ),
  );
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
                    label: Text(
                      Localizations.localeOf(context).languageCode == 'fr'
                          ? 'Copier'
                          : 'Copy',
                    ),
                  ),
                ],
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRetry,
                child: Text(
                  Localizations.localeOf(context).languageCode == 'fr'
                      ? 'Réessayer'
                      : 'Retry',
                ),
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
