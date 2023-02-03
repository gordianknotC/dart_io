
import 'dart:io';

abstract class PlatformSketch{
  Map<String, String> get environment;
  bool get isMacOS;
  Uri get script;
  bool get isWeb;
  bool get isWindows ;
  bool get isLinux;
  bool get isAndroid ;
}

typedef TGetApplicationDocumentsDirectory = Future<Directory?> Function();

