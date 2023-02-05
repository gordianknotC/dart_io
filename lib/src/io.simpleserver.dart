import 'dart:io';
import 'dart:async';

import 'package:dart_io/src/io.cmd.dart';
import 'package:dart_io/src/io.codecs.dart';
import 'package:dart_io/src/typedefs.dart';
import 'package:yaml/yaml.dart';
import 'package:http_server/http_server.dart';
import 'package:path/path.dart';
import 'package:dart_io/src/io.yamlconfig.dart';
import 'package:dart_io/src/io.path.dart';
import 'package:dart_io/src/io.walk.dart';
import 'package:rxdart/rxdart.dart' show BehaviorSubject;

enum Events{
   modified, created, moved, deleted, error, done
}

enum IDE {
   jetbrain, vscode
}

class FileEvent{
   File file;
   Events evt;
   String? msg;
   FileEvent(this.file, this.evt, this.msg);
}

class WatchServer extends StaticServer{
   late Shell             shell;
   YamlMap?           parsedYaml;
   YamlConfig?        yconfig;
   DirectoryWatcher?  dwatcher;
   StreamController<FileEvent>  _stream_ctrl = BehaviorSubject<FileEvent>();
   Stream<FileEvent>   get file_stream => _stream_ctrl.stream;
   Sink<FileEvent>     get file_sink   => _stream_ctrl.sink;

   WatchServer(
    String YAML_PTH, 
    String ROOT,
      {  
        bool clearOnEvent = true, 
        IDE ide = IDE.jetbrain,
        bool considerCached = true, 
        int decay = 400
      }) : super(rootPath: getScriptPath(Platform.script))
   {
      shell = Shell();
      _init(YAML_PTH, ROOT, clearOnEvent, ide, considerCached);
   }
   
   _yamlInit(String YAML_PTH, IDE ide, bool considerCache) async {
      YAML_PTH = Path.join(Directory.current.path, YAML_PTH);
      await File(YAML_PTH).readAsString().then((str) {
         parsedYaml  = loadYaml(str);
         yconfig     = YamlConfig(parsedYaml, YAML_PTH);
      });
      print('YAML_PTH: $YAML_PTH');
      /*if (considerCache){
         var suffix = ide == IDE.jetbrain ? '___jb_tmp___' : (){
            throw Exception('IDE support other than jetbrain is not implemented yet');
         }();
         yconfig.fileptns;
         yconfig.settings.file_pattern = yconfig.settings.file_pattern.map((ptn){
            return ptn + suffix;
         }).toList();
      }*/
   }
   
   _init(String YAML_PTH, String ROOT, bool clearOnEvent, IDE ide, bool considerCache) async {
      await _yamlInit(YAML_PTH, ide, considerCache);
      assert(yconfig != null);
      var dwatcher = DirectoryWatcher( config: yconfig!, decay: 1000);
      print('ROOT    : $ROOT');
      print('CURRENT : ${Directory.current.path}');
      print('PATTERNS: ${dwatcher.file_patterns?.toList()}');
      print('INCLUDES: ${dwatcher.includes.toList()}');
      print('EXCLUDES: ${dwatcher.excludes.toList()}');
      
      void task(String name, File file, Events evt, String? msg){
         if (clearOnEvent)
            shell.clearConsole();
         print('\t$name: ${file.path}, error_msg:$msg');
         if (msg == null)
            return file_sink.add(FileEvent(file, evt, msg));
         _stream_ctrl.addError(msg, StackTrace.fromString(msg));
      }
      
      dwatcher
         ..onFileModified((stream, file, [ msg]){
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
      
      await start();
      server?.close().then((e){
         _stream_ctrl.close();
         print('close streams');
      });
   }
}


class FileArchiveStaticServer{
   late String           rootPath;
   late VirtualDirectory root;
   HttpServer? server;
   String?     serverPath;
   List<TFileSystemEntity>? currentDirs;
   List<TFileSystemEntity>? currentFiles;
   void Function(HttpRequest req)? _onRequest;
   
   FileArchiveStaticServer({String? pth}){
      rootPath = Path.dirname(pth ?? "./")  ; //join(dirname(Platform.script.toFilePath()));
      root     = VirtualDirectory(rootPath);
      root.allowDirectoryListing = true;
      print('rootPath: ${join(dirname(Platform.script.toFilePath()))}');
      print('rootPath: $rootPath');
      print('rootPath: ${root.root}');
   }
   
   Future<TEntity> walk([String? dir]){
      return walkDir(Directory(join(rootPath, "." + (dir ?? ""))), recursive: false).then((TEntity data){
         currentDirs = data.dirs ?? [];
         currentFiles = data.files ?? [];
         return data;
      });
   }
   
   String getRequestPath(HttpRequest req){
      return join(rootPath, '.' + req.uri.toString());
   }
   void serveRequestFile(HttpRequest req){
   		final url = req.uri.toString();
   		final basedir = Path.join(root.root, '.' + Path.dirname(url));
   		if (url.contains('?')){
   			final command = url.split('?').last;
				print('command: $command, basedir: $basedir');
				switch (command){
					case 'decode':
						try {
							final request_file = File(Path.join(basedir, Path.basename(url.split('?').first)));
							final file 				 = File(Path.join(basedir, '__decode__.txt'));
							final encodedString = request_file.readAsStringSync();
							final decodedString = Crypto.decompress(encodedString, encrypt: true);
							print('decoded string: $decodedString');
							file.writeAsStringSync(decodedString);
							root.serveFile(file, req);
						} catch (e) {
							final file = File(Path.join(basedir, '__error__.txt'));
							file.writeAsStringSync(e.toString() );
							root.serveFile(file, req);
						}
						break;
					default:
						final file = File(Path.join(basedir, '__error__.txt'));
						file.writeAsStringSync('invalid command: ${url.split('?').last}');
						root.serveFile(file, req);
						return;
				}
				return;
			}
      root.serveFile(File(getRequestPath(req)), req);
   }
   
   void onRequest(void on_request(HttpRequest req)){
      _onRequest = on_request;
   }
   
   void _on_request (HttpRequest req){
      print('rootPath: ${join(dirname(Platform.script.toFilePath()))}');
      print('rootPath: $rootPath');
      print('rootPath: ${root.root}');
      
      var pth = getRequestPath(req);
      FileSystemEntity entity = FileSystemEntity.isDirectorySync(pth)
        ? Directory(pth)
        : File(pth);
      
      final target = TEntity(entity: entity);
      print('\t'
          'on request: $pth, ${req.uri.toString()}, '
          'isDir:${target.isDirectory}, '
          'isFile:${target.isFile}');
      print('root.root: ${root.root}');
      if (target.isFile)
         serveRequestFile(req);
      else
         root.serveRequest(req);
      
   }
   
   void stop(){
      server?.close.call(force: true);
   }
   
   Future start({int port = 4048} ) async {
   		serverPath = 'http://127.0.0.1:$port';
      server = await HttpServer.bind('0.0.0.0', port, shared: true);
      print('Listening on http://localhost:$port\npath to build:${rootPath}');
      await for (var request in server!) {
         _on_request(request);
      }
   }
}

class StaticServer{
   late String rootPath;
   late VirtualDirectory root;
   String? serverPath;
   HttpServer? server;
   void Function(HttpRequest req)? _onRequest;
   
   StaticServer({String? rootPath}){
      this.rootPath = rootPath ?? join(dirname(Platform.script.toFilePath()));
      this.root     = VirtualDirectory(rootPath);
   }
   
   String getRequestPath(HttpRequest req){
      return join(rootPath, '.' + req.uri.toString());
   }
   void serveRequestFile(HttpRequest req){
      root.serveFile(File(getRequestPath(req)), req);
   }
   
   void onRequest(void on_request(HttpRequest req)){
      _onRequest = on_request;
   }
   
   void _on_request (HttpRequest req){
      if (_onRequest != null) return _onRequest!.call(req);
      //print('request: ${req.uri}');
      var pth = getRequestPath(req);
      print('on request > : $pth');
      serveRequestFile(req);
   }
   
   void stop(){
      server?.close(force: true);
   }
   
   Future start({int port = 4048} ) async {
      print(InternetAddress.loopbackIPv4.address);
      print(InternetAddress.loopbackIPv4.rawAddress);
      serverPath = 'http://localhost:$port';
      
      server = await HttpServer.bind('0.0.0.0', port, shared: true, );
      print('Listening on $serverPath');
      await for (var request in server!) {
         _on_request(request);
      }
   }
}


