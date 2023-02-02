import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';
import 'package:IO/src/io.cmd.dart';

void TestCase_ShellTest() {
   Shell shell;
   
   group('Test Shell and CommonEnv', (){
      setUp((){
         shell = Shell();
      });
      tearDown((){
         shell.close();
      });
      test('using shell with dir and cls', () async {
         shell.input('dir');
         shell.std_stream.listen((cmd){
            if (cmd.name != 'dir' || cmd.ext_code == 0) return;
            var actual = cmd.data;
            print('dir:\n${actual}');
            expect(actual, isNotEmpty);
         });
         await Future.delayed(Duration(milliseconds: 1000));
         shell.clearConsole();
         shell.std_stream.listen((cmd){
            if (cmd.name != 'cls') return;
            print('clear: ${cmd.data}, ${cmd.ext_code}, ${cmd.error}');
            print(stdout.toString());
         });
         await Future.delayed(Duration(milliseconds: 1000));
      });
   });
}