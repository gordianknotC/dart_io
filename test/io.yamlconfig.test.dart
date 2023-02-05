import 'dart:io';
import 'package:test/test.dart';
import 'package:dart_io/src/io.dart' as io;
import 'package:dart_io/src/io.yamlconfig.dart';

import 'package:yaml/yaml.dart' show   loadYaml;
//@fmt:off
const expect_project_root = "E:\\MyDocument\\Dart\\myPackages\\IO";
final expect_proot_gptn = expect_project_root.replaceAll('\\', '/');

final ROOT     = Directory.current.path;
final CURRENT  = io.Path.join(ROOT, 'test');
const FOLDER   = 'watchedFolder';
const FILENAME = 'dump.json';
final WATCH_PTH= io.Path.join(CURRENT, FOLDER);
final DUMP_PTH = io.Path.join(CURRENT, FOLDER, FILENAME);
final YAML_PTH = io.Path.join(CURRENT, FOLDER, 'test.yaml');

const DATA = r"""
name: vuedart_transformer_setting
## all data within variables can be referenced via $"dollar sign"
variables:
  components: ./components/**
  assets    : ./assets
  wfolder   : ./watchedFolder
  sub       : $wfolder/subFolder
  notExist  : $sub/hello
  test      : ../test
settings:
  folders:
    sub       : [$sub]
    components: [$components]
    watch     : [$wfolder]
    assets    : [assets]
    test      : [$test]
  ignored_folders:
    ignored   : [$wfolder/subFolder/**]
  file_pattern: [ '*.vue', '*.dart', '*.txt']
""";

const DATA2 = r"""
name: vuedart_transformer_setting
## all data within variables can be referenced via $"dollar sign"
variables:
  components: ./test/components/**
  assets    : ./test/assets
  wfolder   : ./test/watchedFolder
  sub       : $wfolder/subFolder
  notExist  : $sub/hello
  test      : ./test
settings:
  folders:
    sub       : [$sub]
    components: [$components]
    watch     : [$wfolder]
    assets    : [$assets]
    test      : [$test]
  ignored_folders:
    ignored   : [$wfolder/subFolder/**]
  file_pattern: [ '*.vue', '*.dart', '*.txt']
""";



TestCase_YamlConfigTest(){
   var basepath = CURRENT;
   var YAML = YamlConfig(loadYaml(DATA), CURRENT);
   var YAML2 =YamlConfig(loadYaml(DATA2), '.');
   
   
   generalTest(YamlConfig yaml, String root_path){
      test('validating variables.keys',(){
         var actual   = yaml.variables.keys.toList();
         var expected =[r'$notExist', r'$assets', r'$test', r'$wfolder', r'$sub', r'$components'];
         expect(actual, expected);
      });
      
      
      
      test('validating folders', (){
         var actual   = yaml.folders;
         var expected = [
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\assets',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder\\subFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\components\\'
          ];
         expect(actual, expected);
      });
      
      test('validating ignored_folders', (){
         var actual   = yaml.ignored;
         var expected = ['E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder\\subFolder\\'];
         expect(actual, expected);
      });
      
      test('validating file_pattern', (){
         var actual   = yaml.fileptns;
         var expected = [ '*.vue', '*.dart', '*.txt'];
         expect(actual, expected);
      });
      
      test('validating flatten_allowed', (){
         var actual   = yaml.settings.flatten_allowed;
         var expected = [
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\assets',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder\\subFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\components\\'
          ];
         expect(actual, expected);
      });
      
      test('validating allowed_glob', (){
         var actual   = yaml.settings.allowed_glob;
         var expected = [
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\assets',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\watchedFolder\\subFolder',
            'E:\\MyDocument\\Dart\\myPackages\\IO\\test\\components\\**'
          ];
         expect(actual, expected);
      });
      
      test('validating allowed glob patterns', (){
         var actual   = yaml.includes.map((g) => g.pattern).toList();
         var expected = [
            r'E:/MyDocument/Dart/myPackages/IO/test/assets/*',
            r'E:/MyDocument/Dart/myPackages/IO/test/*',
            r'E:/MyDocument/Dart/myPackages/IO/test/watchedFolder/*',
            r'E:/MyDocument/Dart/myPackages/IO/test/watchedFolder/subFolder/*',
            r'E:/MyDocument/Dart/myPackages/IO/test/components/**'
          ];
         expect(actual, expected);
      });
      
      test('validating ignored glob patterns', (){
         var actual   = yaml.excludes.map((g) => g.pattern).toList();
         var expected = [ r'E:/MyDocument/Dart/myPackages/IO/test/watchedFolder/subFolder/**'];
         expect(actual, expected);
      });
   }
   group('Parsing YamlConfig', (){
      test('validating root path', (){
         print('ROOT: $ROOT');
         print('CURRENT: $CURRENT');
         print('basepath: $basepath');
         expect(YAML.root_path, basepath);
      });
      test('validating variables.values', (){
         var actual   = YAML.variables.values.toList();
         var expected =[
            './watchedFolder/subFolder/hello',
            './assets',
            '../test',
            './watchedFolder',
            './watchedFolder/subFolder',
            './components/**'
          ];
         expect(actual, expected);
      });
      generalTest(YAML, basepath);
   });
   
   group('Parsing YamlConfig with basepath of "."', (){
      test('validating root path', (){
         print('ROOT: $ROOT');
         print('CURRENT: $CURRENT');
         print('basepath: $basepath');
         expect(YAML2.root_path, ROOT);
      });
      test('validating variables.values', (){
         var actual   = YAML2.variables.values.toList();
         var expected =[
            './test/watchedFolder/subFolder/hello',
            './test/assets',
            './test',
            './test/watchedFolder',
            './test/watchedFolder/subFolder',
            './test/components/**'
          ];
         expect(actual, expected);
      });
      generalTest(YAML2, CURRENT);
   });
   
}