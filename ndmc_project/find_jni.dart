
import 'dart:io';
import 'package:yaml/yaml.dart';

void main() {
  final content = File('pubspec.lock').readAsStringSync();
  final yaml = loadYaml(content);
  final packages = yaml['packages'];
  for (var name in packages.keys) {
    var package = packages[name];
    if (package['description'] != null && package['description'] is Map) {
      print('Package ');
    }
  }
}

