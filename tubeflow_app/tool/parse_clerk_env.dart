import 'dart:convert';
import 'dart:io';

import 'package:clerk_auth/clerk_auth.dart';

void main(List<String> args) {
  final path =
      args.isNotEmpty ? args.first : '/tmp/tubeflow-clerk-environment.json';
  final raw = File(path).readAsStringSync();
  final json = jsonDecode(raw) as Map<String, dynamic>;

  try {
    final env = Environment.fromJson(json);
    stdout.writeln('ok');
    stdout.writeln('strategies=${env.strategies}');
    stdout.writeln('social=${env.socialConnections.map((e) => e.name).toList()}');
  } catch (error, stackTrace) {
    stderr.writeln('parse failed: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}
