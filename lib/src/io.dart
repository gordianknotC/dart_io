
export 'package:dart_io/src/io.yamlconfig.dart' show
   YamlConfig;

export 'package:dart_io/src/io.glob.dart' show
   GlobMatcher, GlobPtnRectifier, systemsep, globsep, contrasep, convertIntoGlobPath, convertIntoSystempath;

export 'package:dart_io/src/io.path.dart' show
   rectifyPathSeparator, getScriptPath, dumpMapToJSON, getScriptUri, Path,
   readFileAsString, readFileAsStringSync, readJSONtoMap, yamlListToList, dump;

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



