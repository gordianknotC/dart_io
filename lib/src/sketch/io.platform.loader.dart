
import 'io.platform.sketch.dart';

class Platform implements PlatformSketch{
  // ignore: missing_return
  @override Map<String, String> get environment => {};
  // ignore: missing_return
  @override bool get isMacOS => false;
  // ignore: missing_return
  @override Uri get script => Uri();
  // ignore: missing_return
  @override bool get isWeb => false;
  // ignore: missing_return
  @override bool get isAndroid => false;
  // ignore: missing_return
  @override bool get isLinux => false;
  // ignore: missing_return
  @override bool get isWindows => false;
}

TGetApplicationDocumentsDirectory	getApplicationDocumentsDirectory = () => Future.value();