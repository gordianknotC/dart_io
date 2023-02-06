import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dart_io/dart_io.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject;

final _ENV_NODE = Platform.isWindows ? 'NODE_PATH' : 'PATH',
      _ENV_DART = 'DART_SDK',
      _ENV_PATH = Platform.isWindows ? 'Path' : 'PATH',
      _ESEP     = Platform.isWindows ? ';' : ':';

///
/// [node_path] - 取得 node path
/// [dart_sdk] - 取得 dart sdk
/// [path] - 取得 PATH
///
class CommonEnv {
   Map<String, String> env = {};
   
   String get node_path {
      final path = env[_ENV_NODE];
      assert(path != null);
      var nodepath = parsePath(path!).first;
      if (Platform.isWindows) return parentPath(nodepath);
      return nodepath;
   }
   String get dart_sdk{
      final path = env[_ENV_DART];
      assert(path != null);
      return parsePath(path!).first;
   }
   String get path {
      final path = env[_ENV_PATH];
      assert(path != null);
      return path!;
   }
   void set node_path(String v) => env[_ENV_NODE] = v;
   void set path     (String v) => env[_ENV_PATH] = v;
   void set dart_sdk (String v) => env[_ENV_DART] = v;
   
   String parentPath(String path, [int level = 1]){
      var level_op = '../' * level;
      return Path.join(path.substring(0, path.length), level_op);
   }
   
   List<String> parsePath(String path){
      return path.split(_ESEP);
   }
   
   String operator [](Object key) {
      final path = env[key];
      assert(path != null);
      return path!;
   }
  
  operator []=(String left, String right){
      env[left] = right;
  }

   CommonEnv({
      String? node_path,
      String? path,
      String? dart_sdk
   }){
      var e = Platform.environment;
      env = {
         _ENV_NODE: node_path ?? e[_ENV_NODE]!,
         _ENV_DART: dart_sdk  ?? e[_ENV_DART]!,
         _ENV_PATH: path      ?? e[_ENV_PATH]!,
      };
   }
}

class CmdEvent{
   ///
   String   name;
   String?   data;
   bool     is_stdin;
   int?      ext_code;
   String?   error;
   bool get isOK     => error == null && ext_code == 0;
   bool get isFailed => !isOK;
   
   CmdEvent({
      required this.name,
      this.data,
      this.is_stdin = false,
      this.ext_code,
      this.error
   });
}
///
/// ### Example
/// ```dart
/// shell.input('dir');
/// shell.std_stream.listen((cmd){
///     if (cmd.name != 'dir' || cmd.ext_code == 0) return;
///     final data = cmd.data;
///     print('dir:\n${data}');
///     expect(data, isNotEmpty);
/// });
/// ```
///
class Shell{
   CommonEnv env;
   StreamController<CmdEvent>? _controller = BehaviorSubject<CmdEvent>();
   Stream<CmdEvent> get std_stream => _controller!.stream;
   Sink<CmdEvent>   get std_sink   => _controller!.sink;
   
   clearConsole() async {
      //await input('cls', [], null, true);
      if(Platform.isWindows) {
         print(Process.runSync("cls", [], runInShell: true).stdout);
         print("\x1B[2J\x1B[0;0H");
         print("_");
      } else {
         print(Process.runSync("clear", [], runInShell: true).stdout);
         print("\x1B[2J\x1B[0;0H");
         print("_");
      }
   }
   
   input(String exe, [List<String>? arguments, String? _stdin, bool streaming = true]) async {
      arguments ??= [];
      await Process.start(
         exe,
         arguments,
         runInShell:  true,
         environment: env.env
      ).then((process) async {
         if (_stdin != null){
            process.stdin.add(AsciiCodec().encode(_stdin));
            // await process.stdin.add(AsciiCodec().encode(_stdin));
            print('before close');
            await process.stdin.close();
            print('closed');
         }
         process.stdout.listen((data){
            if (!streaming) return;
            var output = AsciiCodec().decode(data);
            std_sink.add(
               CmdEvent(name: exe, data: output)
            );
         }).onError((e){
            if (!streaming) return;
            _controller!.addError(e, StackTrace.fromString(e));
         });
         process.exitCode.then((code){
            if (!streaming) return;
            std_sink.add(
               CmdEvent(name: exe, ext_code: code)
            );
         });
         process.stderr.listen((data){
            if (!streaming) return;
            var output = AsciiCodec().decode(data);
            _controller!.addError(output, StackTrace.fromString(output));
         });
         return process;
      });
   }
   
   close(){
      _controller!.close();
      _controller = null;
   }

   Shell(): env = CommonEnv();
}

