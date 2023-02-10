撰寫 IO 相關工具，版本目前過舊待更新，細部使用見 test, 待補足 test 後 publish 。


## Usage
```yaml
dart_io:
  git:
    url: https://github.com/gordianknotC/dart_io.git
    refs: master
```


## Todo
- [V] 更新 dart sdk
- [ ] 重新 確認/補足 unittest

## 目錄
- [io.cmd](#io.cmd--cmd-test)
    - [CommonEnv](#CommonEnv)
    - [Shell](#Shell)
- [io.codecs](#io.codecs--codec-test)
    - [Img](#Img)
    - [Crypto](#Crypto)
- [io.glob](#io.glob--glob-test)
    - [MGlobMatcher](#MGlobMatcher)
    - [GlobPtnRectifier](#GlobPtnRectifier)
- [io.util](#io.util)
    - [Path](#Path) 
- [io.simpleserver](#io.simpleserver--watch-test)
    - [WatchServer](#WatchServer)
    - [FileArchiveServer](#FileArchiveServer)
    - [StaticServer](#StaticServer)
- [io.walk](#io.walk--fileio-test)
    - [DirectoryWatcher](#DirectoryWatcher)
    - [DirectoryWalker](#DirectoryWalker)
    - [StaticServer](#StaticServer)
- [io.platform](#io.platform--platform-test)
- [io.yamlconfig](#io.yamlconfig--yaml-test)


## io.cmd | [cmd-test]

### CommonEnv
讀取常用 env, 如 DART_SDK | NODE_PATH | PATH
> source
```dart
///
/// [node_path] - 取得 node path
/// [dart_sdk] - 取得 dart sdk
/// [path] - 取得 PATH
/// 
class CommonEnv {}
```

###  Shell 
可執行 shell 並將 shell stdin | stdout 轉接至 StreamController 以利外部偵聽, StreamController 會以 CmdEvent 收發事件.

> source
```dart
class CmdEvent{
    String   name;
    String   data;
    bool     is_stdin = false;
    int      ext_code;
    String   error;
    bool get isOK     => error == null && ext_code == 0;
    bool get isFailed => !isOK;
}
class Shell{
  CommonEnv env;
  StreamController<CmdEvent>? _controller = BehaviorSubject<CmdEvent>();
  Stream<CmdEvent> get std_stream => _controller!.stream;
  Sink<CmdEvent>   get std_sink   => _controller!.sink;
  clearConsole() async { }
  input(String exe, [List<String>? arguments, String? _stdin, bool streaming = true]) async {  }
  close(){ }
  Shell(): env = CommonEnv();
}
```
#### Example
```dart
shell.input('dir');
shell.std_stream.listen((cmd){
    if (cmd.name != 'dir' || cmd.ext_code == 0) return;
    final data = cmd.data;
    print('dir:\n${data}');
    expect(data, isNotEmpty);
});
```

## io.codecs | [codec-test]
###  Img
載入 image 並可轉換為 datauri | bytes

> source
```dart
class Img {
    static String getPath(String pth) { }
    static Future<Img> loadAsync(String pth) { }
    static Img loadSync(String pth) { }
    String get datauri { }
    Uint8List get bytes {  }
    void dumpAsText() {  }
}
```

#### Example
  ```dart
  Img.loadAsync('./assets/newsicon.png').then((image) {
      print('image.path: ${image.path}');
      print('image.bytes: ${image.bytes}');
      print('image.uri: ${image.datauri}');
  });;
  ```

###  Crypto
1) 以 [BlockCipher] 加密解密
2) 加密後壓縮 | 解壓縮後解密

> source
```dart
class Crypto {
   static List<int> toBytes(String source) { }
   static XtoY(Encoding x, Codec y, String source){ }
   static String utf8ToBase64(String source) { }
   static String base64ToUtf8(String source) {  }
   static String compress(String source, {bool encrypt = false}) {  }
   static String decompress(String source, {bool encrypt = false}) { }
   static encrypt(String source, String key) {  }
   static String decrypt(String source, String key) { }
   static getCryptoKey(String name) { }
}
```
##### Example:
  ```dart
  final key         = 'knot';
  final origContent = Crypto.compress((File(path).readAsStringSync()));
  final encrypt     = Crypto.encrypt(origContent, key);
  final decrypt     = Crypto.decrypt(encrypt, key);
  ```

## io.glob | [glob-test]
### MGlobMatcher
glob pattern matcher, M開頭代表 Mixin，包含 includes pattern 及 excludes pattern, 提供 isIncluded/isExcluded 方法，判定是否在這二者內，提供 isPermitted 方法判定是否只在 isIncluded 而沒有在 isExcluded 內. 

```dart
test('test GlobMatcher for validating whether a glob pattern is within '
  'an allowed pattern and excluded by disallowed pattern', (){
  final folder = '$expect_proot_gptn/lib/src/components/hellocomp';
  final isIncluded = yconfig.isIncluded(folder);
  expect(isIncluded, isTrue);
  expect(yconfig.isIncluded('$expect_proot_gptn/lib/src/components/uiState'),       isTrue);
  expect(yconfig.isIncluded('$expect_proot_gptn/lib/src/components/uiState/hello'), isTrue);
  expect(yconfig.isPermitted('$expect_proot_gptn/lib/src/components/uiState'),       isFalse);
  expect(yconfig.isPermitted('$expect_proot_gptn/lib/src/components/uiState/hello'), isFalse);
});
```
### GlobPtnRectifier | [glob-test]
將 glob pattern 轉成 absolute 同時考慮到 ../ ./ 這一類的操作
1) Rewrite Miss-joined Path like
    - "e:/path/to/somewhere/../../skip/here" into
    - "e:/path/skip/here"
2) by default, asterisk pattern is added at the end if it is considered to be a folder
    - transform "e:/path/skip/here" into "e:/path/skip/here/*"
如下

```dart
final pth = "$expect_proot_gptn/test/./watchedFolder/../../lib/src/**";
final r = GlobPtnRectifier(pth);
expect(r.lastSegment, equals("**"));
expect(r.path, equals("$expect_proot_gptn/lib/src/**"));

final pth2 = "$expect_proot_gptn/test/./watchedFolder/../../lib/src/";
final r2 = GlobPtnRectifier(pth2);
expect(r2.lastSegment, equals("src"));
expect(r2.path, equals("$expect_proot_gptn/lib/src/*"));
```
## io.util
###  Path
file path operation
> source
```dart
/// dump string to file
Future<String> dump(String data, File path) {}
/// dump Map object to file
Future<Map> dumpMapToJSON(Map<String, dynamic> data, File path) {}

Future<String> readFileAsString(Uri pathuri, String filename ){}
String readFileAsStringSync(String pathuri, String filename ){}
Future<Map> readJSONtoMap(File path) {}
String combinePath(String path, String sep){}

/// replace unix/windows file path separator with system recognizable one
String rectifyPathSeparator(String path){}

/// get current script path, no matter where the project root is.
/// EX:
/// ``` dart
/// getScriptPath(Platform.script)
/// ```
String getScriptPath(Uri uri, [String? script_name]) {}
Uri getScriptUri(Uri uri, String script_name){}

class Path{
  static String? rectifyPath(String? a){ }
  static String join(String a, String b, [String? c]){  }
  static String dirname(String a, {bool absolute = false, String? ext}){ }
  static Uri toUri(String a){  }
  static String fromUri(Uri uri){ }
  static absolute(String path){  }
  static String basename(String path){  }
  static bool isAbsolute(String path){ }
  static bool isRelative(String path){  }
}
```

#### Example
```dart
test('path join operation1', (){
  var base = r'E:\MyDocument\Dart\myConsoleApps\vueconsole';
  var rel  = '../vueconsole';
  var rel2 = '../../myConsoleApps';
  
  expect(
    Path.join(base, rel),
    r'E:\MyDocument\Dart\myConsoleApps\vueconsole'
  );
  
  expect(
    Path.join(base, rel2),
    r'E:\MyDocument\Dart\myConsoleApps'
  );
});
```

## io.simpleserver.dart [watch-test]

### WatchServer
```dart
WatchServer(
  String YAML_PTH, 
  String ROOT,
    {  
      bool clearOnEvent = true, 
      IDE ide = IDE.jetbrain,
      bool considerCached = true, 
      int decay = 400
    }) : super(rootPath: getScriptPath(Platform.script))
```
以下為所偵聽的 file event 事件，內部 event 則以 Shell CmdEvent StreamController 偵聽
```dart
dwatcher
  ..onFileModified((stream, file, [msg]){
    task('modified', file, Events.modified, msg);
  })
  ..onFileCreated((stream, file, [msg]){
    task('created', file, Events.created, msg);
  })
  ..onFileDeleted((stream, file, [msg]){
    task('deleted', file, Events.deleted, msg);
  })
  ..onFileMoved((stream, file, [msg]){
    task('moved', file, Events.moved, msg);
  })
  ..onError((stream, file, [msg]){
    task('error', file, Events.error, msg);
  })
  ..onDone((stream, file, [msg]){
    task('done', file, Events.done, msg);
  })
  ..watch();
```

#### Example
```dart
final ROOT     = Directory.current.path;
final CURRENT  = io.Path.join(ROOT, 'test');
final YAML_PTH = io.Path.join(CURRENT, 'watcherspec.yaml');

if (arguments.length == 1 && arguments[0] == '-directRun') {
  var server = await io.WatchServer(YAML_PTH, ROOT);
  // await io.StaticServer().start();
}
```
### FileArchiveServer
### StaticServer

## io.walk.dart [fileio-test]

### DirectoryWatcher
#### Example
```dart
final dwatcher = DirectoryWatcher(dirs: dirs, config: yconfig)
  ..onFileModified((stream, file, [msg]){
    modified.add(file.path);
    print('\tDetect file modified: ${file.path}, modified:$modified');
  })
  ..onFileCreated((stream, file, [msg]){
    created.add(file.path);
    print('\tDetect file created: ${file.path}, created:$created');
  })
  ..onFileDeleted((stream, file, [msg]){
    deleted.add(file.path);
    print('\tDetect file deleted: ${file.path}');
  })
  ..watch();
```
### DirectoryWalker
#### Example
```dart
test('Test stream eventA - walking through directories by feeding stream event;'
    '\nLet predefined glob patterns fetching for right patterns and store it as '
    'result by returning true within user callback of onFileWalk and onDirectoryWalk.', () async {
  Completer completer = Completer<TEntity>();
  // "$expect_project_root\\lib .parent"
  print('dwalker.root_dir.parent.parent: ${dwalker.root_dir.parent.parent}');
  
  TEntity result = TEntity(entity: dwalker.root_dir.parent.parent);
  dwalker
    ..onFileWalk((subscription, root, parent, file){
      switch(parent.path){
          case "$expect_project_root\\test\\assets":
            expect(asset_files, contains(path.basename(file.path)));
            break;
          case "$expect_project_root\\test\\components":
            expect(comp_files, contains(path.basename(file.path)));
            break;
          case "$expect_project_root\\lib":
            expect(lib_files, contains(path.basename(file.path)));
            break;
      }
      print("continuum on file: ${file.path}");
      return true;
    })
    ..onDirectoryWalk((subscription, root, parent, current){
      print("continuum on directory: ${current.path}");
      return true;
    });
  var ret = {};
  Stream<TEntity> receiver =  dwalker.feed();
  await receiver.listen((TEntity data){
        result = data;
        if (data.isDirectory){
          ret[data.label] = data.asMap;
        }else{
          ret.addAll(data.asMap);
        }
        print("data: ${data}");
        print('ret: \n$ret');
    }, onDone:() {
        var keys = ret.keys.toList();
        print('onDone, keys: $keys');
        lib_files.forEach((file){
          expect(keys, unorderedEquals(['Directory: assets', 'Directory: components', 'Directory: lib']));
        });

        var src = ret['Directory: lib']['Directory: src'];
        expect(src.keys, unorderedEquals([
          'File: io.cmd.dart',
          'File: io.codecs.dart',
          'File: dart_io.dart',
          'File: io.glob.dart',
          'File: io.simpleserver.dart',
          'File: io.path.dart',
          'File: io.walk.dart',
          'File: io.yamlconfig.dart'
        ]));
        
        var assets = ret['Directory: assets'];
        expect(assets.keys?.toList(), equals([]), reason: 'expect no file pattern matched within assets folder'); //note: no file patterns matched
        
        var comp = ret['Directory: components'];
        expect(comp.keys?.toList(), equals(['File: testcomp.vue']), reason: 'expect only testcomp.vue matched within components folder');
        
        completer.complete(result);
    });
    return completer.future;
  } );
```

## io.platform [platform-test]
支援 web/mobile
```dart
export 'sketch/io.platform.loader.dart'
if (dart.library.io) 'mobile/io.platform.mobile.dart'
if (dart.library.html) 'web/io.platform.web.dart';
```

介面
```dart
abstract class PlatformSketch{
  Map<String, String> get environment;
  bool get isMacOS;
  Uri get script;
  bool get isWeb;
  bool get isWindows ;
  bool get isLinux;
  bool get isAndroid ;
}
```


## io.yamlconfig.dart [yaml-test]

### YamlConfig




[tracker]: http://example.com/issues/replaceme
[cmd-test]: ./test/io.cmd.test.dart
[codec-test]: ./test/io.codec.test.dart
[glob-test]: ./test/io.glob.test.dart
[logger-test]: ./test/io.logger.test.dart
[fileio-test]: ./test/fileio.test.dart
[watch-test]: ./test/watchServer.test.dart
[path-test]: ./test/tempPath.test.dart
[yaml-test]: ./test/io.yamlconfig.test.dart
