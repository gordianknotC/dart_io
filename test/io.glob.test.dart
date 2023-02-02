
import 'package:IO/src/io.glob.dart';
import 'package:test/test.dart';
import 'package:IO/src/io.yamlconfig.dart';
import 'package:IO/src/io.path.dart' show Path;
import 'package:yaml/yaml.dart' show  loadYaml;
import 'io.yamlconfig.test.dart' show CURRENT, DATA;


TestCase_GlobPatternTest(){
   var basepath = CURRENT;
   var yaml = YamlConfig(loadYaml(DATA), CURRENT);
   var includes = yaml.includes.toList();
   var excludes = yaml.excludes.toList();
   
   group('Test io.path', (){
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
   });
   group("Test GlobPtn", (){
      test("", (){
        final path1 = "hello/world";
        final ptn1 = GlobPtnRectifier(path1);

        final path2 = "hello/world/";
        final ptn2 = GlobPtnRectifier(path2);
  
        expect(ptn1.closePath(path1), path1);
      });
   });
   
   group('Test GlobPattern for pattern matching "/*"', (){
      var ptn = includes[0];
      test('expect following glob pattern being used in following tests',(){
         print('glob pattner: $ptn');
         expect(ptn.pattern, 'E:/MyDocument/Dart/myPackages/IO/test/assets/*');
      });
      
      test('expect test pattern matched for hello segment',(){
         var actual = ptn.hasMatch('E:/MyDocument/Dart/myPackages/IO/test/assets/hello');
         var expected = true;
         expect(actual, expected);
      });

      test('expect test pattern doesnt matched for hello/word segment',(){
         var actual = ptn.hasMatch('E:/MyDocument/Dart/myPackages/IO/assets/hello/word');
         var expected = false;
         expect(actual, expected);
      });
   });

   group('Test GlobPattern for pattern matching "/**"', (){
      var ptn = includes[4];
      test('expect following glob pattern being used in following tests',(){
         print('glob pattner: $ptn');
         expect(ptn.pattern, 'E:/MyDocument/Dart/myPackages/IO/test/components/**');
      });
   
      test('expect test pattern matched for hello segment',(){
         var actual = ptn.hasMatch('E:/MyDocument/Dart/myPackages/IO/test/components/hello');
         var expected = true;
         expect(actual, expected);
      });
   
      test('expect test pattern matched for hello/word segment',(){
         var actual = ptn.hasMatch('E:/MyDocument/Dart/myPackages/IO/test/components/hello/word');
         var expected = true;
         expect(actual, expected);
      });
   });
}