
export 'package:dart_io/src/io.yamlconfig.dart' ;
export 'package:dart_io/src/io.glob.dart' ;
export 'package:dart_io/src/io.path.dart' ;

export 'package:dart_io/src/io.walk.dart' show
   DirectoryWalker, BaseStreamPublisher, BaseStreamReader,
   DirectoryWatcher, FileNotExistsError, walkDir;

export 'package:dart_io/src/io.simpleserver.dart' show StaticServer, WatchServer, Events, FileEvent;
export 'package:dart_io/src/io.cmd.dart' show Shell;
export 'package:dart_io/src/typedefs.dart';

//@fmt:on
void main([arguments]) {
   if (arguments.length == 1 && arguments[0] == '-directRun') {
   }
}



