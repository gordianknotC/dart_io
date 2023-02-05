import 'dart:io' show Directory, File, FileSystemEntity, FileSystemEvent, Platform;
import 'dart:async' show Stream, StreamController;
import 'dart:async' show Completer, StreamTransformer, EventSink, StreamSubscription;

import 'package:IO/src/typedefs.dart';
import 'package:quiver/pattern.dart';
import 'package:path/path.dart' as Path;

import 'package:common/src/common.log.dart' show ELevel, Logger;
import 'package:common/src/common.dart';
import 'package:common/src/common.fn.dart';
import 'package:IO/src/io.glob.dart';
import 'package:IO/src/io.yamlconfig.dart';
import 'package:IO/src/io.path.dart';


class FileNotExistsError extends Error {
	Object? message;
	FileNotExistsError([this.message]);
	
	String toString() => "[FileNotExistsError] \n$message";
}


/*
   an overview of how StreamController work, fetched from stackOverflow;
   ---------------------------------------------------------------------
   Publisher publisher = new Publisher();
   
   Reader john = new Reader('John');
   Reader smith = new Reader('Smith');
   
   publisher.onPublish.listen(john.read);
   publisher.onPublish.listen(smith.read);
   
   for (var i = 0; i < 5; i++) {
      publisher.publish("Test message $i");
   }
*/
class BaseStreamPublisher {
	StreamController<String> _publishCtrl = new StreamController<String>();
	late Stream<String> onPublish;
	
	BaseStreamPublisher() {
		onPublish = _publishCtrl.stream;
		//onPublish = _publishCtrl.stream.asBroadcastStream();
	}
	
	void publish(String s) {
		_publishCtrl.add(s);
	}
}

class BaseStreamReader {
	String name;
	
	BaseStreamReader(this.name);
	
	read(String s) {
		print("My name is $name. I read string '$s'");
	}
}


//@fmt:off


/*
   Ex:
      dir = Directory(CURRENT);
      await walkDir(dir, recursive: true).then((data) {
         print('fetched files: $data');
      });
   ________________________________________________________________________
   
   Ex:
      specify recorder to automatically record all the files and directories
      that have been walking through
      ----------------------------------------------------------------------
      dir = Directory(CURRENT);
      recorder = <String, FileSystemEntity>{}
      await walkDir(dir, recursive: true, recorder).then((data) {
      });
   ________________________________________________________________________
   
   Ex:
      specify conditioning callback to determine weather walking recursively
      or not
      ----------------------------------------------------------------------
      dir = Directory(CURRENT);
      recorder = <String, FileSystemEntity>{}
      continuum = (Directory dir, Map<String, FileSystemEntity> recorder){
         return true_to_walk_further_false_to_interrupt;
      }
      await walkDir(dir, recursive: true, recorder).then((data) {
      });
   
   [NOTE]
         about return type::
            type TRet = Map<String, FileSystemEntity | TRet>
   
*/

Future<TEntity> walkDir(Directory dir,
		{bool symlink = false, TEntity? recorder,
			bool recursive = false, TWalkContinue? continuum,
			bool cancelOnError = false
}) async {
	//--------------------------------------------
	List<FileSystemEntity> folders = [];
	Completer<TEntity> completer = Completer<TEntity>();
	try {
		recorder ??= TEntity(entity: dir);
	} catch (e) {
		throw new Exception('$e\nType Cast Error, be sure to provide a specific '
				'type as a generic type when using walkDir\n');
	}
	print('\nwalkDir recursive:$recursive :');
	
	if (!dir.existsSync()) {
		throw FileNotExistsError("dir not exists: ${dir.path}");
		/*completer.completeError( "dir not exists: ${dir.path}" );
      return completer.future;*/
	}
	
	Stream<FileSystemEntity>receiver = dir.list(recursive: recursive, followLinks: symlink);
	
	late StreamSubscription<FileSystemEntity> subscription;
	subscription = receiver.listen((FileSystemEntity entity) {
		if (entity is Directory) {
			recorder!.dirs?.add(TDirectory(entity: entity));
			folders.add(entity);
		} else {
			//determines weather to record file or not
			if (continuum == null || continuum(dir: dir, file: entity as File, subscription: subscription))
				recorder!.files?.add(TFile(entity: entity));
		}
		print('walkDir, onProgress ${entity.path}');
	}, onDone: () {
		var completed = 0;
		var l = folders.length;
		print('walkDir process folders,  folders:$l, recursive:$recursive');
		if (l == 0 || recursive == true) {
			return completer.complete(recorder);
		};
		void appendDone() {
			completed += 1;
			if (completed == l) {
				print('walkDir onDone!! recorder: $recorder');
				completer.complete(recorder);
				subscription.cancel();
			}
		}
		if (!recursive) return;
		
		for (var i = 0; i < l; ++i) {
			var _folder = folders[i];
			var _recorder = recorder![_folder] as TEntity;
			// determines weather to walk into directory or not
			print('prepare to walk on directory');
			if (continuum == null || continuum(dir: _folder as Directory, subscription: subscription) == true) {
				print('\twalk on Directory: ${_folder.path}');
				walkDir(_folder as Directory, recorder: _recorder,
						symlink: symlink,
						recursive: recursive,
						continuum: continuum,
						cancelOnError: cancelOnError).then((data) {
					appendDone();
				});
			} else {
				appendDone();
			}
		}
	}, onError: (e) {
		throw new Exception('[walkDir]\nSome error occured while walking directory: $dir, \nerrorCode:$e');
	}, cancelOnError: cancelOnError);
	return completer.future;
} //@fmt:on


class DirectoryWalker<T_config extends YamlConfig> {
	//@fmt:off
	Set <FileSystemEntity>? _files;
	late List<Directory> _dirs_to_walk;
	Directory? _root_dir;
	T_config? _configs;
	Iterable<Glob>? _file_patterns;
	Map cache = {};
	
	bool Function(StreamSubscription subscription, Directory root, Directory parent, File file)? _onFileWalk;
	bool Function(StreamSubscription subscription, Directory root, Directory parent, Directory current)? _onDirectoryWalk;
	
	//bool Function()                                                      ;
	
	//region: cached properties
	Directory get root_dir {
		if (_root_dir != null) return _root_dir!;
		if (_configs == null) return _root_dir = _inferRootDir();
		_root_dir = Directory(_configs!.root_path);
		return _root_dir!;
	}
	
	void set root_dir(Directory v) {
		_root_dir = v;
	}
	
	List<Directory> get dirs_to_walk {
		if (_dirs_to_walk != null)
			return _dirs_to_walk;
		throw new Exception('DirectoryWatcher.dirs_to_walk not initialized yet!');
	}
	
	void set dirs_to_walk(List<Directory> v) {
		_dirs_to_walk = v;
	}
	
	T_config get configs {
		if (_configs != null) return _configs!;
		throw new Exception('DirectoryWatcher.configs not initialized yet!');
	}
	
	void set configs(T_config v) {
		_configs = v;
	}
	
	Iterable<Glob>? get file_patterns {
		if (_file_patterns != null)
			return _file_patterns!;
		final ptn = configs.settings.file_pattern;
		return _file_patterns = ptn == null ? null : ptn.map((_ptn) => Glob(_ptn));
	}
	
	Iterable<Glob> get excludes {
		return configs.excludes;
	}
	
	Iterable<Glob> get includes {
		return configs.includes;
	}
	
	Set<FileSystemEntity> get files {
		if (_files != null) return _files!;
		throw new Exception('DirectoryWatcher._files not initialized yet!');
	}
	
	void set files(Set<FileSystemEntity> v) {
		_files = v;
	}
	
	//endregion: cached
	
	//region: public computed properties:: dirs_streams
	/*
   [NOTE]
      An Example showing how to use Streams
      -------------------------------------------------------
      import 'dart:async';
   
      Stream<int> change(Stream<Iterable> stream) {
        return stream.transform(new StreamTransformer<Iterable, int>.fromHandlers(
            handleData: (Iterable iter, EventSink<int> sink) {
          sink.add(iter.length);
        }));
      }
      
      void main() {
        Stream<Iterable> stream = new Stream<List<String>>.fromIterable([
          ["hello", "world"],
          "I have a dream".split(' ')
        ]);
        var result = change(stream.map<Iterable>((x) => x));
        result.listen(print);
      }
   ______________________________________________________
      output:
         2
         4
      
   [NOTE]
      #### An Example Showing how to Create Stream from Future List
      -------------------------------------------------------------
      
      Stream<T> streamFromFutures<T>(Iterable<Future<T>> futures) async* {
        for (var future in futures) {
          var result = await future;
          yield result;
        }
      }
   [NOTE]
      about return type::
         type TRet = Map<String, FileSystemEntity | TRet>
   */
	Stream<TEntity> get dir_streams async* {
		print('\t dirs to walk: $dirs_to_walk');
		Iterable<Future<TEntity>>futures = dirs_to_walk.map((Directory dir) => walk(dir: dir));
		try {
			for (var future in futures) {
				var result = await future;
				yield result;
			}
		} catch (e) {
			raise(e);
		}
	}
	
	//endregion: public and computed properties ::::
	
	//region: constructor:: factory, configInit, _configInit
	/*
      [Description]
         feed DirectoryWatcher with [List<Directory>] or [T_config]
   */
	DirectoryWalker({List<Directory>? dirs, T_config? config}) {
		if (config == null && dirs == null)
			throw Exception("Either dirs or config can be optional, not both.");
		if (config != null)
			configs = config;

		_dirs_to_walk = dirs ?? (config?.folders.map((x) {
			var d = Directory(x);
			d.exists().then((is_exists) {
				if (!is_exists);
			}, onError: (e) =>
					raise('$e\n'
							'directory: $d setup in yaml config not exists!'
							'config folders: ${config.folders}'));

			return d;
		}).toList() ?? []);
	}
	
	//endregion: constructor
	
	//region: public methods:: feed, onFile, onDirectory, walk, watch, get
	
	/*
      [Description]
      handy cache, cache for fetching parent directory via Directory entity.
      ---------------------------------------------------------------------
      [Example]
      var parent = get(Directory dir, () => dir.parent);
   */
	T _get<T>(key, T getter()) {
		if (cache.containsKey(key)) return cache[key];
		cache[key] = getter();
		return cache[key];
	}
	
	/*
      [Description]
      publish stream event into receiver.
      --------------------------------------------------------
      [Example]
      wa = DirectoryWatcher(dirs: dirs, config: yconfig)
         .onFileWalk((root, parent, file){
         
         })
         .onDirectoryWalk(root, parent, dir){
         
         }
         .onCancelWalk(){
            //todo
         }
      receiver = wa.feed();
      receiver.listen((Map<String, FileSystemEntity> data){
      
      });
      
      [NOTE]
         about return type::
            type TRet = Map<String, FileSystemEntity | TRet>
   */
	Stream<TEntity> feed() {
		return dir_streams.transform(StreamTransformer<TEntity, TEntity>.fromHandlers(handleData: (TEntity data, EventSink<TEntity> sink) {
			sink.add(data);
		}));
	}
	
	bool isFileMatched(String file_path) {
		var filename = GlobPtnRectifier(file_path).last;
		var ret = (file_patterns?.any((Glob glob) {
			return glob.hasMatch(filename);
		}) ?? false);
		//print('path:$file_path, matched: $ret');
		return ret;
	}
	
	bool isDirIncluded(String dir_path) {
		return includes.any((glob) => glob.hasMatch(dir_path));
	}
	
	bool isDirExcluded(String dir_path) {
		return excludes.any((glob) => glob.hasMatch(dir_path));
	}
	
	/* [Description]
      set callbacks called on walking every file.
      ------------------------------------------------------
      [NOTE]
      1) return true to continue exploring and let glob patterns filtering which
         tobe included/excluded, return false to skip walking through current
         directory and ignore glob pattern filtering process.
      2) use subscription.cancel() to interrupt the whole stream process.
   */
	onFileWalk(TOnFile onfile) {
		_onFileWalk = onfile;
	}
	
	onDirectoryWalk(TOnDir ondir) {
		_onDirectoryWalk = ondir;
	}
	
	/*
      [NOTE]
         about return type::
            type TRet = Map<String, FileSystemEntity | TRet>
   */
	Future<TEntity> walk({required Directory dir}) async {
		Completer<TEntity> completer = Completer<TEntity>();
		YamlConfig? cfg = _configs;
		Directory root = _configs != null ? Directory(_configs!.root_path) : dir;

		final TWalkContinue continuum = ({required subscription, required dir, File? file}){
			if (file != null) { // to collect specific file types or not
				if (file_patterns == null)
					return true;
				
				var is_walkOnFile_passed = _onFileWalk?.call(subscription, root, dir, file);
				if (is_walkOnFile_passed == false) return false;
				return isFileMatched(file.path);
			} else if (dir != null) { //to walk into further
				if (cfg == null)
					return true;
				var parent = _get<Directory>(dir, () => dir.parent);
				var is_walkOnDir_passed = _onDirectoryWalk?.call(subscription, root, parent, dir);
				var dir_name = GlobPtnRectifier(dir.path).path;
				if (is_walkOnDir_passed == false) return false;
				return cfg.isPermitted(dir_name);
			} else {
				throw Exception('Invalid Usge, parameters of either Directory or File should be provided');
			}
		};
		if (dir.existsSync()) {
			walkDir(dir, recursive: false, continuum: continuum).then((TEntity data) {
				data.files?.map((f) => f.entity);
				Iterable<File> temp = data.files?.map((f) => f.entity as File) ?? [];
				_files ??= Set<FileSystemEntity>();
				_files!.addAll(temp);
				completer.complete(data);
			});
		} else {
			completer.completeError(FileNotExistsError("directory ${dir.path} not exists"));
		}
		return completer.future;
	}
	
	//endregion: public methods
	
	//region: private methods:: _inferRootDir
	Directory _inferRootDir() {
		List<Tuple<Directory, int>> paths_to_walk, sorted, shortest_list;
		if (dirs_to_walk != null && dirs_to_walk.isEmpty)
			throw Exception('Uncaught exceptions, directories not initialized yet');

		paths_to_walk = dirs_to_walk.map((d) => Tuple(d, GlobPtnRectifier(d.path).segment_length)).toList();
		sorted = FN.sorted(paths_to_walk, (a, b) => (a.value ?? 0) - (b.value ?? 0));
		shortest_list = sorted.where((data) => data.value == sorted[0].value).toList();
		if (shortest_list.length > 1) {
			final parent = GlobPtnRectifier(shortest_list[0].key.path).parent_segment;
			return shortest_list.every((data) => GlobPtnRectifier(data.key.path).parent_segment == parent)
				? shortest_list[0].key
				: () {
						throw Exception("Cannot infer root path by resolving following paths: ${shortest_list}");
					}();
		} else if (shortest_list.length == 1) {
			return sorted[0].key;
		} else {
			throw Exception('Uncaught error while inferring root dir');
		}
	}
//endregion: private methods
}


/*
   [Description]
      watch on file changed according on a given yamlConfig inherited from DirectoryWalker
   
   [Example]
      dwatcher = DirectoryWatcher(dirs, yamlconfig)
      dwatcher.onFileCreated((subscribtion, file){
         //your code here...
         //use subscription.cancel() to interrupt watch process.
      });
      dwatcher.onFileModified();
      dwatcher.watch();

*/


class DirectoryWatcher extends DirectoryWalker<YamlConfig> {
	TOnFileChanged? _onFileCreated;
	TOnFileChanged? _onFileModified;
	TOnFileChanged? _onFileDeleted;
	TOnFileChanged? _onFileMoved;
	TOnFileChanged? _onDone;
	TOnFileChanged? _onError;
	Map<String, int> _file_info = {};
	bool _cancel = false;
	int decay;
	
	bool get cancel {
		return _cancel;
	}
	
	void set cancel(bool v) {
		_cancel = v;
	}
	
	DirectoryWatcher({List<Directory>? dirs, YamlConfig? config, this.decay = 400}) : super(dirs: dirs, config: config);
	
	
	onFileCreated(TOnFileChangedWrapper cb) {
		_onFileCreated = _getWrappedOnFileCB(cb);
	}
	
	onFileModified(TOnFileChangedWrapper cb) {
		_onFileModified = _getWrappedOnFileCB(cb);
	}
	
	onFileDeleted(TOnFileChangedWrapper cb) {
		_onFileDeleted = _getWrappedOnFileCB(cb);
	}
	
	onFileMoved(TOnFileChangedWrapper cb) {
		_onFileMoved = _getWrappedOnFileCB(cb);
	}
	
	onDone(TOnFileChangedWrapper cb) {
		_onDone = _getWrappedOnFileCB(cb);
	}
	
	onError(TOnFileChangedWrapper cb) {
		_onError = _getWrappedOnFileCB(cb);
	}
	
	watch() {
		print('WATCH::');
		feed().listen((TEntity data) {
			print('Initializing directories completed, start watching following directories for changes');
			print('\tdirectories: ${data}; waiting for changes...');
			//_processFetchedValue(TEntity(entity: dirs_to_walk[1]));
			_processFetchedValue(TEntity(entity: data.entity));
		}, onDone: () {
		
		}, onError: (e) {
			raise(e);
		});
	}
	
	void _processFetchedValue(TEntity entity) {
		late StreamSubscription subscription;
		if (entity.isDirectory) {
			print('\twatch on path:${entity.entity.path}');
			subscription = entity.entity.watch().listen((FileSystemEvent event) {
				if (!event.isDirectory) {
					var file = File(event.path);
					var matched = isFileMatched(file.path);
					if (matched) print('caught event: $event.path');
					switch (event.type) {
						case FileSystemEvent.create:
						//print('created: $matched');
							if (matched) _onFileCreated?.call(subscription, file, true);
							break;
						case FileSystemEvent.modify:
						//print('modified: $matched');
							if (matched) _onFileModified?.call(subscription, file);
							break;
						case FileSystemEvent.delete:
						//print('deleted: $matched');
							if (matched) _onFileDeleted?.call(subscription, file, true);
							break;
						case FileSystemEvent.move:
						//print('moved: $matched');
							if (matched) _onFileMoved?.call(subscription, file, true);
							break;
					}
				}
			}, onDone: () {
				_onDone?.call(subscription, entity.entity as File, true);
			}, onError: (e) {
				_onError?.call(subscription, entity.entity as File, true, e);
				raise('error on file stream:\n$e');
			});
			subscription.onError((e) {
				raise('error on file stream:\n$e');
			});
			//entity.values.forEach(_processFetchedValue);
		}
	}
	
	int _now() =>
			DateTime
					.now()
					.millisecondsSinceEpoch;
	
	TOnFileChanged _getWrappedOnFileCB(TOnFileChangedWrapper cb) {
		return (StreamSubscription stream, File file, [bool? delay_ignored, String? message]) {
			return guard(() {
				if (cancel) {
					stream.cancel();
					return;
				}
				if (_file_info.containsKey(file.path) && delay_ignored == false) {
					var div = _now() - (_file_info[file.path] ?? 0);
					if (div < decay) {
						return;
					}
				}
				if (delay_ignored == false) _file_info[file.path] = _now();
				cb(stream, file, message);
			}, 'Exceptions occurs on file streams callbacks', error: 'FileStreamError', raiseOnly: true);
		};
	}
}


void main(arguments) {
	if (arguments.length == 1 && arguments[0] == '-directRun') {
		var dir = getScriptPath(Platform.script);
		print('dir: $dir');
//      var walker = DirectoryWalker(
//         dirs: [Directory(dir)]
//      );
		walkDir(Directory(dir), recursive: false).then((TEntity data) {
			var total = 0;
			data.files?.forEach((e) {
				var lines = (e.entity as File)
						.readAsStringSync()
						.split('\n')
						.where((l) => !l.trim().startsWith('/'))
						.length;
				print('file: ${Path.basename(e.entity.path)}, lines: $lines');
				total += lines;
			});
			print('sum: $total');
		});
	}
}





