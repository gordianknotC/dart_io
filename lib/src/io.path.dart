import 'package:yaml/yaml.dart' show YamlList, YamlMap;
import 'dart:async' show Future;
import 'dart:io' show File;
import 'dart:convert' show json;
import 'package:path/path.dart' as NPath;
import 'package:dart_io/src/io.glob.dart' as Glob;

//final _log = _.Logger(name: "io", levels: [_.ELevel.critical, _.ELevel.error, _.ELevel.warning]);



/*
---------------------------------------


          conversion utils            ;
---------------------------------------
for converting yaml type into dart type
---------------------------------------
*/

List<T>? yamlListToList<T>(YamlList? list) {
   //@fmt:off
   if (list == null) return null;
   try {
      return List<T>.from(list);
   } on Exception catch(e){
      if (T == String)  return List<T>.from(list.map((x) => x.toString()));
      if (T == List)    return List<T>.from(list.map((x) => x.toList()));
      if (T == Map)     return List<T>.from(list.map((x) => Map.from(x)));
      throw new Exception('$e\nType Unsupported, only String, List, and Map are supported. You provide: ${list.runtimeType}');
   } catch(e){
      rethrow;
   }
}     //@fmt:on

Map<String, List<T>>? yamlMapToMap<T>(YamlMap? map) {
   if (map == null) return null;
   return Map<String, dynamic>.from(map).map((k, v) =>
      MapEntry<String, List<T>>(k, List<T>.from(v))
   );
}

final sep = NPath.separator;
final rsep = sep == r'\'
           ? r'/'
           : r'\';

/*
---------------------------------------------


                 File IO utils              ;
---------------------------------------------
for reading/writing files from/into Yaml/Json
---------------------------------------------
*/

Future<String> dump(String data, File path) {
   return path.exists().then((exists) {
      Future<String> write(File file) {
         return file.writeAsString(data).then((File _file) {
            return data;
         }, onError: (e) => throw Exception(e));
      }
      if (!exists) {
         return path.create().then(write);
      } else {
         return write(path);
      }
   });
}

Future<Map> dumpMapToJSON(Map<String, dynamic> data, File path) {
   return path.exists().then((exists) {
      var JSON = json.encode(data);
      Future<Map> write(File file) {
         return file.writeAsString(JSON).then((File _file) {
            return json.decode(JSON);
         }, onError: (e) => throw Exception(e));
      }
      if (!exists) {
         return path.create().then(write);
      } else {
         return write(path);
      }
   });
}


Future<String>
readFileAsString(Uri pathuri, String filename ){
   var current_path = getScriptPath(pathuri);
   return File(NPath.join(current_path, filename)).readAsString().then((str){
      return str;
   }, onError: (e) => throw Exception(e));
}

String
readFileAsStringSync(String pathuri, String filename ){
   var file = File(NPath.join(pathuri, filename));
   
   if (!file.existsSync())
      throw Exception(
         StackTrace.fromString('\nFile: ${filename} not found')
      );
   return File(NPath.join(pathuri, filename)).readAsStringSync();
}

Future<Map> readJSONtoMap(File path) {
   return path.readAsString().then((str) {
      return json.decode(str);
   }, onError: (e) => throw Exception(e));
}


String combinePath(String path, String sep){
   var paths = path.split(sep);
   var new_paths = [];
   if (path.startsWith('.')){
      new_paths.add(paths[0]);
   }
   paths.forEach((pth){
      //print('pth:$pth, new_paths: $new_paths, path:$path');
      if (pth == '..'){
         if(new_paths.length > 1) new_paths.removeLast();
         return;
      }
      if (pth == '.')
         return;
      new_paths.add(pth);
   });
   //print('end: ${new_paths.join(sep)}');
   return new_paths.join(sep);
}

String rectifyPathSeparator(String path) {
   //orig:  if (!path.contains(sep))
   if (path.contains(rsep))
      path = path.replaceAll(rsep, sep);
   return path;
   //return combinePath(path, sep);
}

/*
   get current script path, no matter where the project root is.
   EX:
      getScriptPath(Platform.script)
*/
String getScriptPath(Uri uri, [String? script_name]) {
   if (script_name == null)
      return rectifyPathSeparator(
         NPath.dirname(uri.toString()).split('file:///')[1]
      );
   return NPath.join(rectifyPathSeparator(
      NPath.dirname(uri.toString()).split('file:///')[1]
   ), script_name);
}

Uri getScriptUri(Uri uri, String script_name){
   var path = getScriptPath(uri, script_name);
   return Uri.file(path);
}


class Path {
   static String? rectifyPath(String? a){
      if (a == null) return a;
      if (a.startsWith('file:'))
         a = a.split('file:///')[1];
      return rectifyPathSeparator(a);
   }
   
   static String join(String a, String b, [String? c]){
      //print('join a: $a, b:$b');
      return combinePath(NPath.join(
         rectifyPath(a),
         rectifyPath(b),
         rectifyPath(c)
      ), sep);
   }
   
   static String dirname(String a, {bool absolute = false, String? ext}){
      if (absolute)
         a = Path.absolute(a);
      // specify file extension, to determine whether it's a file or directory
      // if it's a directory then to find it's dirname is unexpected.
      if (ext != null){
         if (!a.endsWith(ext))
            return rectifyPath(a)!;
      }
      return NPath.dirname(rectifyPath(a));
   }
   
   static Uri toUri(String a){
      if (!a.startsWith('file:'))
         a = 'file:///$a';
      return NPath.toUri(a);
   }
   
   static String fromUri(Uri uri){
      return rectifyPath(NPath.fromUri(uri))!;
   }
   
   static absolute(String path){
      return combinePath(
         rectifyPath(
            Glob.absolute(path)
         )!, sep);
   }
   
   static String basename(String path){
      return NPath.basename(path);
   }
   
   static bool isAbsolute(String path){
      return NPath.isAbsolute(path);
   }
   
   static bool isRelative(String path){
      return NPath.isRelative(path);
   }
}
















