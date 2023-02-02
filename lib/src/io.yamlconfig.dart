import 'dart:io' show File;
import 'package:yaml/yaml.dart' show YamlMap, loadYaml;
//import 'package:path/path.dart' as Path;
import 'package:IO/src/io.path.dart';
import 'package:IO/src/io.glob.dart';


/*
-------------------------------------------------

              Type definitions                   ;
_YamlConfig,  GlobPtnRectifier, GlobMatcher
-------------------------------------------------
*/ //@fmt:off
abstract class ISettings {
   List<String>               _flatten_allowed; //actually it's List<String>, but cannot found a way to cast YamlList into List<String>
   List<String>               _flatten_forbidded;
   List<String>               _allowed_glob;
   List<String>               _forbid_glob;
   List<String>               file_pattern;
   Map<String, List<String>>  folders;
   Map<String, List<String>>  ignored_folders;
   //bool                       recursive;
   List<String> get allowed_glob;
   List<String> get forbid_glob;
   List<String>
   get flatten_allowed;
   
   void
   set flatten_allowed(List<String> v);
   
   List<String>
   get flatten_forbidded;
   
   void
   set flatten_forbidded(List<String> v);
}

class TSettings implements ISettings{
   List<String>               _flatten_allowed; //actually it's List<String>, but cannot found a way to cast YamlList into List<String>
   List<String>               _flatten_forbidded;
   List<String>               _allowed_glob;
   List<String>               _forbid_glob;
   List<String>               file_pattern;
   Map<String, List<String>>  folders;
   Map<String, List<String>>  ignored_folders;
   //bool                       recursive;
   List<String> get allowed_glob => _allowed_glob;
   List<String> get forbid_glob => _forbid_glob;
   
   List<String>
   get flatten_allowed => _flatten_allowed;
   
   void
   set flatten_allowed(List<String> v) {
      _flatten_allowed = v;
   }
   
   List<String>
   get flatten_forbidded => _flatten_forbidded;
   
   void
   set flatten_forbidded(List<String> v) {
      _flatten_forbidded = v;
   }
   
   String _deGlobPtn(String ptn){
      if (ptn.endsWith('**'))
         ptn = ptn.substring(0, ptn.length - 2);
      if (ptn.endsWith('*'))
         ptn = ptn.substring(0, ptn.length - 1);
      return ptn;
   }
   
   renderFolders(Map<String, List<String>>_path_folders,
                 List<String> _path_list, List<String>_glob_list,
                 Map<String, String> vars, String basepath){
      _path_folders.forEach((k, List<String>v) {
         _path_folders[k] = v.map((path) {
            if (vars.keys.contains(path))
               path = vars[path];
            vars.keys.forEach((key){
               if (path.contains(key))
                  path = path.replaceAll(key, vars[key]);
            });
            String glob_path = Path.absolute(Path.join(basepath, path));
            String deglob    = _deGlobPtn(glob_path);
            _glob_list.add(glob_path);
            _path_list.add(deglob);
            return deglob;
            //return _deGlobPtn(absolute(path, basepath));
         }).toList();
      });
   }
   TSettings(YamlMap data, String basepath, Map<String, String> vars) {
      file_pattern    = yamlListToList(data['file_pattern']);
      folders         = yamlMapToMap(data['folders']);
      ignored_folders = yamlMapToMap(data['ignored_folders']);
      //recursive       = data['recursive'] as bool;
      var folders_glob = <String>[];
      var folders_list = <String>[];
      var ignored_glob = <String>[];
      var ignored_list = <String>[];
      renderFolders(folders, folders_list, folders_glob, vars, basepath);
      renderFolders(ignored_folders, ignored_list,  ignored_glob, vars, basepath);
      
      _allowed_glob = folders_glob;
      _forbid_glob  = ignored_glob;
      _flatten_allowed   = folders_list;//folders.values.toList().fold([], (prev, elt) => prev + elt);
      _flatten_forbidded = ignored_list;//ignored_folders.values.toList().fold([], (prev, elt) => prev + elt);
   }
}

class KW {
   static String vars = 'variables';
   static String settings = 'settings';
   static String recursive = 'recursive';
   static String folders = 'folders';
   static String ignored_folders = 'ignored_folders';
   static String file_pattern = 'file_pattern';
}
/*
   [Description]
      Specific yaml config parser for vue dart.
      
   [NOTE]
      Prefixed with M denotes for Mixin.
*/
class MYamlConfig {
   YamlMap yaml;
   Map<String, String>  variables;
   ISettings            settings;
   String               name;
   String               root_path;

   List<String> get folders => settings.flatten_allowed;
   List<String> get ignored => settings.flatten_forbidded;
   List<String> get fileptns => settings.file_pattern;
   
   renderVariable(){
      variables.forEach((var_name, raw_value){
         variables.forEach((key, value_mayhas_var){
            if (value_mayhas_var.contains(var_name)){
               variables[key] = value_mayhas_var.replaceAll(var_name, raw_value);
            }
         });
      });
   }
  
   Init_YamlConfig(dynamic path_or_yaml, [String source_path]){
      init(YamlMap data, String source_path){
         yaml = data;
         root_path = source_path;
         name = data['name'] as String;
         variables = Map.from(data['variables']).map((k, v) {
            k = r'$' + k.toString();
            return MapEntry(
               k, v
            );
            /*return MapEntry(k,
               v.contains(r'$')
               ? absolute(v, root_path, true)
               : absolute(v, root_path));*/
         });
         renderVariable();
         /*variables.forEach((_key, val) {
            if (val.contains(r'$')) {
               var k = variables.keys.firstWhere((key) => val.contains(key));
               variables[_key] = val.replaceFirst(k, variables[k]);
            }
         });*/
         
         settings = TSettings(data['settings'], root_path, variables);
      }
   
      if (path_or_yaml is String) {
         var str = File(path_or_yaml).readAsStringSync();
         if (!Path.isAbsolute(path_or_yaml))
            path_or_yaml = Path.absolute(path_or_yaml);
         init(loadYaml(str), Path.dirname(path_or_yaml));
      } else if (path_or_yaml is YamlMap) {
         if (source_path == null)
            throw Exception('source_path could not be null while initializing _YamlConfig by YamlMap');
       
         source_path = Path.dirname(source_path, absolute: true, ext: '.yaml');
         init(path_or_yaml, source_path);//Path.dirname(source_path));
      } else {
         throw new Exception('Unsupported type while initializeing _YamlConfig');
      }
   }
}

class YamlConfig extends MYamlConfig with MGlobMatcher{
   YamlConfig (dynamic path_or_yaml, [String source_path]){
      Init_YamlConfig(path_or_yaml, source_path);
      Init_GlobMatcher(
         includes_pattern: settings._allowed_glob,
         excludes_pattern: settings._forbid_glob
      );
   }
}

//@fmt:on