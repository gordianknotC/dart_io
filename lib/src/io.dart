
export 'package:IO/src/io.yamlconfig.dart' show
   YamlConfig;

export 'package:IO/src/io.glob.dart' show
   GlobMatcher, GlobPtnRectifier, systemsep, globsep, contrasep, convertIntoGlobPath, convertIntoSystempath;

export 'package:IO/src/io.path.dart' show
   rectifyPathSeparator, getScriptPath, dumpMapToJSON, getScriptUri, Path,
   readFileAsString, readFileAsStringSync, readJSONtoMap, yamlListToList, dump;

export 'package:IO/src/io.walk.dart' show
   DirectoryWalker, BaseStreamPublisher, BaseStreamReader,
   DirectoryWatcher, FileNotExistsError, walkDir;

export 'package:IO/src/io.simpleserver.dart' show StaticServer, WatchServer, Events, FileEvent;

export 'package:IO/src/io.cmd.dart' show Shell;
export 'package:IO/src/typedefs.dart';


//@fmt:on

void main([arguments]) {
   if (arguments.length == 1 && arguments[0] == '-directRun') {
   }
}



