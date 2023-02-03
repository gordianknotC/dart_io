import 'dart:io' show Directory, File, FileSystemEntity, FileSystemEvent, Platform;
import 'dart:async' show Completer, StreamTransformer, EventSink, StreamSubscription;

import 'package:IO/src/io.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as _Path;

typedef TWalkContinue   = bool Function({required StreamSubscription subscription, required Directory dir, File? file});
typedef TWalkCB         = bool Function(Directory root, Directory current, List<FileSystemEntity> filesOrDirs);
typedef TWatchCB        = bool Function(List<FileSystemEntity> changed_files);


abstract class TFileSystemEntity {
	late FileSystemEntity    entity;
	List<TFileSystemEntity>?   files ;
	List<TFileSystemEntity>?   dirs  ;
	String?                  _label;
	late int                 _level;
	String   get label;
	String   get path        => entity.path;
	bool     get isFile      => entity is File;
	bool     get isDirectory => entity is Directory;
	
	String
	get _filelabel{
		return 'File: ${_Path.basename(path)}';
	}
	String
	get _dirlabel{
		return 'Directory: ${_Path.basename(path)}';
	}
	Iterable<String>
	get keys {
		return [files ?? [], dirs ?? []].expand((x) => x).map((x) =>  x.label);
	}
	
	Iterable<TFileSystemEntity>
	get values{
		return [files ?? [], dirs ?? []].expand((x) => x).map((x) =>  x);
	}
	
	Iterable<MapEntry<String, TFileSystemEntity>>
	get mapEntries{
		return [files ?? [], dirs ?? []].expand((x) => x).map((x) =>  MapEntry(x.label, x));
	}
	Map<String, TFileSystemEntity>
	get asMap {
		return Map.fromEntries(mapEntries);
	}
	
	TFileSystemEntity
	operator [](dynamic labelOrEntity) {
		if (labelOrEntity is FileSystemEntity){
			return labelOrEntity is File
				? (files ?? []).firstWhere((f) => f.entity == labelOrEntity)
				: labelOrEntity is Directory
					? (dirs ?? []).firstWhere((d) => d.entity == labelOrEntity)
					: (){throw Exception("Unsupported type for indexing");}();
		} else if (labelOrEntity is String){
			var sector = labelOrEntity.substring(0, 5) == 'File:'
				? (files ?? [])
				: labelOrEntity.substring(0, 10) == 'Directory:'
					? (dirs ?? [])
					: (){throw Exception('Invalid label for indexing on TEntity');}();
			return sector.firstWhere((f) => f.label == labelOrEntity);
		}
		throw Exception('Invalid type of indexer for indexing on TEntity');
	}
	add(TFileSystemEntity data){
		if (data.entity is Directory){
			assert(dirs != null);
			data._level = _level + 1;
			dirs!.add(data );
		}else if (data.entity is File){
			assert(files != null);
			data._level = _level;
			files!.add(data);
		}
	}
	
	String _toString(int indent){
		final String TAB = '\t' * indent;
		final String SUB = '\t' * (indent + 1);
		var _files = files != null && files!.length > 0
				? files!.fold('${SUB}files: ', (String all,  entity){
			return '$all\n${entity._toString(indent+2)}';
		})
				: '';
		var _dirs = dirs != null && dirs!.length > 0
				? dirs!.fold('${SUB}dirs: ', (String all,  entity){
			return '$all\n${entity._toString(indent+2)}';
		})
				: '';
		var _content = [_files, _dirs].fold('${TAB}$label: ', (String all, String content){
			return content.isEmpty
					? all
					: '$all\n$content' ;
		});
		return '$_content';
	}
	String toString(){
		return _toString(0);
	}
}

class TEntity extends TFileSystemEntity{
	static bool unitTesting = false;
	static bool serverRun= false;
	static FileSystemEntity Function(FileSystemEntity e) onServerRun = (e) => e;
	static FileSystemEntity Function(FileSystemEntity e) onUnitTesting = (e) => e;
	@override FileSystemEntity entity;
	TEntity({
		required this.entity,
		List<File>? files,
		List<Directory>? dirs,
		int level = 0
	}){
		if (unitTesting) {
			this.entity = onUnitTesting(entity);
		}else if (serverRun){
			this.entity = onServerRun(entity);
		}else{
			this.entity = entity;
		}
		this._level = level;
		if(isDirectory){
			this.files  = (files ?? []).map((f)=> TFile(entity: f, level: level)).toList();
			this.dirs   = (dirs ?? []).map((d) => TDirectory(entity: d, level: level + 1)).toList();
		}
	}
	
	bool sameFile(TEntity entity){
		return this.entity.path == entity.path;
	}
	
	@override
	String get label {
		if (_label != null) return _label!;
		return isFile
				? _label = _filelabel
				: _label = _dirlabel;
	}
	
	// following two: untested:
	@override
	bool operator == (Object other) =>
			other is TEntity &&
					_Path.absolute(entity.path) == _Path.absolute(other.entity.path);
	
	@override
	int get hashCode =>
			entity.path.hashCode;
}

class TFile extends TEntity{
	final FileSystemEntity entity;
	TFile ({
		required this.entity,
		int level = 0
	}) : super(entity: entity, level: level);
	
	String get label {
		if (_label != null) return _label!;
		return _label = _filelabel;
	}
	@alwaysThrows
	add(TFileSystemEntity data) {
		throw Exception("Cannot use 'add' on TFile instance.");
	}
}

class TDirectory extends TEntity {
	TDirectory({
		required Directory entity,
		List<File>? files,
		List<Directory>? dirs,
		int level = 0
	}) : super(entity: entity, files: files, dirs: dirs, level: level);
	
	String get label{
		if (_label != null) return _label!;
		return _label = _dirlabel;
	}
	
	@override
	add(TFileSystemEntity data){
		if (data.entity is Directory){
			assert(dirs != null);
			dirs!.add(data );
		}else if (data.entity is File){
			assert(files != null);
			files!.add(data );
		}
	}
}

//@fmt:off
/*class _DirectoryOpt {
   Directory         dir;
   FileStat          stat;
   bool              recursive;
   String            globptn;
   _DirectoryOpt({this.dir, this.recursive, this.stat, this.globptn});
}*/
//@fmt:on



/*
usage 1)
   - feed watcher with yaml configurations
   ---------------------------------------
   final watcher = DirectoryWatcher();
   watcher.loadConfig(cfg)
   watcher.watch();
   
usage 2)
   watch directories with configurable scripts
   -------------------------------------------
   List<DirectoryOpt> = dirs;
   final watcher = DirectoryWatcher()
   
*/

typedef TOnWalk = bool Function(Directory root, Directory parent, File file);
typedef TOnFile = bool Function(StreamSubscription subscription, Directory root, Directory parent, File file);
typedef TOnDir = bool Function(StreamSubscription subscription, Directory root, Directory parent, Directory current);


typedef TOnFileChangedWrapper = Function(StreamSubscription stream, File file, [String? error_message]);
typedef TOnFileChanged        = Function(StreamSubscription stream, File file, [bool? delay_ignored, String? message]);

