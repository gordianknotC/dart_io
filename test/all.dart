import 'fileio.test.dart' show TestCase_fileIoTest;
import 'io.cmd.test.dart';
import 'io.glob.test.dart';
import 'io.yamlconfig.test.dart';

void main() {
  TestCase_ShellTest();
  TestCase_YamlConfigTest();
  TestCase_GlobPatternTest();
  TestCase_fileIoTest();
}
