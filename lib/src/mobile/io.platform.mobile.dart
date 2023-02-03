library io_simple.mobile;

import 'dart:io' as IO;

import '../sketch/io.platform.sketch.dart';

// import 'package:path_provider/path_provider.dart' as _PV;


class Platform implements PlatformSketch{
	@override Map<String, String> get environment => IO.Platform.environment;
	@override bool get isMacOS => IO.Platform.isMacOS;
	@override bool get isWindows => IO.Platform.isWindows;
	@override bool get isLinux => IO.Platform.isLinux;
	@override bool get isAndroid => IO.Platform.isAndroid;
	@override Uri get script => IO.Platform.script;
  @override bool get isWeb => false;
}

TGetApplicationDocumentsDirectory	getApplicationDocumentsDirectory = (){
	return Future<IO.Directory?>.value();
	// return _PV.getApplicationDocumentsDirectory();
};
