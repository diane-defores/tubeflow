import 'package:flutter/material.dart';

/// Parse a hex color string (e.g. "#8b5cf6") into a [Color].
Color parseHexColor(String hex) {
  final hexCode = hex.replaceFirst('#', '');
  return Color(int.parse('FF$hexCode', radix: 16));
}
