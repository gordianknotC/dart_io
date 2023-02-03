library io_simple.web;

import 'dart:async';
import 'dart:io';

import '../sketch/io.platform.sketch.dart';




class Platform implements PlatformSketch{
	@override Map<String, String> get environment => {'web': ''};
	@override bool get isMacOS => false;
	@override Uri get script => Uri();
	@override bool get isWindows => false;
	@override bool get isLinux => false;
	@override bool get isAndroid => false;
	@override bool get isWeb => true;
	
}

TGetApplicationDocumentsDirectory	getApplicationDocumentsDirectory = (){
	final completer = Completer<Directory>();
	completer.complete(Directory(""));
	return completer.future;
};
