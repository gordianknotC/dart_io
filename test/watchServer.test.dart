import 'dart:async';
import "dart:io";

import 'package:IO/src/io.dart' as io;


void main([arguments]) async {
   final ROOT     = Directory.current.path;
   final CURRENT  = io.Path.join(ROOT, 'test');
   final YAML_PTH = io.Path.join(CURRENT, 'watcherspec.yaml');
   
   if (arguments.length == 1 && arguments[0] == '-directRun') {
      var server = await io.WatchServer(YAML_PTH, ROOT);
//      await io.StaticServer().start();
   }
}
