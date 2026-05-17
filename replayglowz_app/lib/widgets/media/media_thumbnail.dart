import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.borderRadius,
    this.icon = Icons.play_circle_outline,
    this.fit = BoxFit.cover,
  });

  final String? imageUrl;
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final IconData icon;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: width,
      height: height,
      color: colorScheme.surfaceContainerHighest,
      child: Center(child: Icon(icon)),
    );

    Widget child;
    if (imageUrl == null || imageUrl!.isEmpty) {
      child = fallback;
    } else {
      child = CachedNetworkImage(
        imageUrl: imageUrl!,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: colorScheme.surfaceContainerHighest,
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => fallback,
      );
    }

    if (borderRadius == null) {
      return child;
    }
    return ClipRRect(borderRadius: borderRadius!, child: child);
  }
}
