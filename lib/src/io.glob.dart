import 'package:path/path.dart' as Path;
import 'package:quiver/pattern.dart' as Q;
import 'package:IO/src/io.path.dart' as io;
import 'package:common/src/common.log.dart';
import 'dart:io' show Directory;
import 'package:common/src/common.dart';

final _log = Logger(name: "io.glob", levels: [ELevel.critical, ELevel.error, ELevel.warning, ELevel.debug]);


/*
----------------------------------------------------


               glob pattern utils                   ;
-----------------------------------------------------
for rectification of native package of glob pattern ;
-----------------------------------------------------
*/

String get systemsep => Path.separator;

String get globsep => '/';

String get contrasep =>
   systemsep == r'\'
   ? r'/'
   : r'\';

String convertIntoSystempath(String pth) {
   if (!pth.contains(systemsep))
      pth = pth.replaceAll(contrasep, systemsep);
   return pth;
}

String convertIntoGlobPath(String pth) {
   return pth.replaceAll(systemsep, globsep);
}

/// turning path into system recognizable path, which is "absolute path"
String absolute(String pth, [String? basepath, bool? hasVariable]) {
   pth = convertIntoSystempath(pth);
   if (hasVariable == true) return pth;
   return Path.isAbsolute(pth)
          ? pth
          : basepath != null
            ? Path.isAbsolute(basepath)
              ? Path.absolute(basepath, pth)
              : () {
      throw Exception('basepath should be an absolute path');
   }()
            : Path.absolute(pth);
}



const PTN = ['*', '?', '[', ']'];


class GlobPtnRectifier {
   static Map<String, GlobPtnRectifier> cache = {};
   late String _parent_segment;
   String      _sep = globsep;
   String      path;
   List<String> _segments;
   
   factory GlobPtnRectifier(String path){
      if (GlobPtnRectifier.cache.containsKey(path)){
         final data = GlobPtnRectifier.cache[path];
         assert(data != null);
         return data!;
      }
      return GlobPtnRectifier.cache[path] = GlobPtnRectifier.init(path);
   }
   
   GlobPtnRectifier.init(String pth)
       :_segments = [], path = pth
   {
      rectify();
      GlobPtnRectifier.cache[pth] = this;
   }
   
   //region: getters
   int
   get segment_length{
      return _segments.length;
   }
   String get lastSegment {
      var ret = last;
      if (ret == '' || isPattern(ret)) {
         /*ret = _segments[_segments.length - 2];
         if (ret == '')
            throw Exception('Root directory without disk drive label specified!');*/
         return ret;
      }
      return ret;
   }
   
   String? get parent_segment{
      if (_parent_segment != null) return _parent_segment;
      if (_segments.length >= 2){
         _parent_segment =  _segments[_segments.length - 2];
         return _parent_segment;
      }else{
         return null;
      }
   }
   
   String get last {
      return _segments.last;
   }
   
   List<String> get tail {
      return _segments.getRange(0, _segments.length - 2).toList();
   }
   
   List<String> get head {
      return _segments.getRange(1, _segments.length - 1).toList();
   }
   //endregion
   
   //region: condition
   bool isPattern(String segment) {
      return segment.split('').any((String ch) {
         return PTN.any((symbol) => symbol == ch);
      });
   }
   
   bool isEndsWithFolder(String pth) {
      return (isPattern(lastSegment) && !lastSegment.contains('.')) || (!lastSegment.contains('.'));
   }
   //endregion
   
   //region: instance methods

   String closePath(String pth) {
      if (isEndsWithFolder(pth)) {
         _log('lastSegment:$lastSegment, ispattern:${isPattern(lastSegment)}');
         if (!isPattern(lastSegment))
            return '${pth}/*';
         return pth;
      }
      _log('closed path: $pth, _sep:$_sep');
      return pth;
   }

   String absolute(String pth, [String? basepath, bool? hasVariable]) {
      pth = convertIntoSystempath(pth);
      if (hasVariable == true) return pth;
      return convertIntoGlobPath(Path.isAbsolute(pth)
         ? pth
         : basepath != null
            ? Path.isAbsolute(basepath)
               ? Path.absolute(basepath, pth)
               :  () {
                     throw Exception('basepath should be an absolute path');
                  }()
            : Path.absolute(pth));
   }

   ///   -------------------------------------------
   ///   1) Rewrite Miss-joined Path like
   ///       - "e:/path/to/somewhere/../../skip/here" into
   ///       - "e:/path/skip/here"
   ///   2) by default, asterisk pattern is added at the end if it is considered to be a folder
   ///       - "e:/path/skip/here/*"
   ///   -------------------------------------------
   String rectify() {
      path = FN.stripRight(path.replaceAll(r'\', _sep), _sep);
      path = io.combinePath(path, _sep);
      _segments = path.split(_sep);
      path = closePath(path);
      return path;
   }
   //endregion
  
} //@fmt:on

//@fmt:off
class GlobMatcher extends MGlobMatcher{
   GlobMatcher({
      required List<String> includes_pattern,
      required List<String> excludes_pattern
   }){
      Init_GlobMatcher(includes_pattern: includes_pattern, excludes_pattern:  excludes_pattern);
   }
}

///
///   [Description]
///       A Glob pattern matcher, can be used as mixin,
///       design to be considering [includes] pattern not [excludes] pattern
///    [NOTE]
///       Prefixed with M denotes for Mixin.
///
class MGlobMatcher  {
   late Iterable<Q.Glob> includes;
   late Iterable<Q.Glob> excludes;

   Init_GlobMatcher({
      required List<String> includes_pattern,
      required List<String> excludes_pattern
   }){
      includes = includes_pattern.map((ptn) => Q.Glob(GlobPtnRectifier(ptn).path));
      excludes = excludes_pattern.map((ptn) => Q.Glob(GlobPtnRectifier(ptn).path));
      _log('initialize Glob... \nincludes $includes', ELevel.debug);
   }
   
   String _guard<T> (T folder){
      return folder is String
         ? GlobPtnRectifier(folder).path
         : folder is Directory
            ? GlobPtnRectifier(folder.path).path
            :  (){
                  throw Exception('Unsupported type, only String, and Directory are allowed. '
                     '\nYou provide folder:${folder.runtimeType}');
               }();
   }
   
   bool _isXcluded<T>(T folder, Iterable<Q.Glob> compass) {
      String path, glob_pattern;
      glob_pattern = _guard(folder);
      //_log('folder: $folder\nrectified: $glob_pattern', ELevel.debug);
      return compass.any((Q.Glob glob) {
         path = glob.pattern;
         //_log('\nGlob: $path \nmatches: $glob_pattern \nresults: ${Q.Glob(path).hasMatch(glob_pattern)}' );
         return glob.hasMatch(glob_pattern);
      });
   }
   bool isIncluded<T>(T folder) {
      if (includes == null) return true;
      return _isXcluded(folder, includes);
   }
   
   bool isExcluded<T> (T folder){
      if (excludes == null) return true;
      return _isXcluded(folder, excludes);
   }
   /*
      test if a file or folder is matched within allowed_folders
      and not banned out within forbidden_folders.
   */
   bool isPermitted<T>(T file_or_dir) {
      if (isIncluded(file_or_dir)){
         if (!isExcluded(file_or_dir))
            return true;
      }
      return false;
   }
}
