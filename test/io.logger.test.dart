// import 'dart:io';
//
// import 'package:common/common.dart';
// import 'package:test/test.dart';
// import 'package:IO/src/io.path.dart' show Path, getScriptPath;
// import 'package:common/common.dart';
//
//
// final base = '${getScriptPath(Platform.script)}/io_logger_test';
//
//
// void main() {
//    getScriptPath(Platform.script);
//
//    final files = [
//       '$base/log1.log',
//       '$base/log2.log',
//    ];
//    final data = [
//       "1111112345",
//       "8603112345",
//       "3895542345",
//       "0979832345",
//       "0977187415",
//       "1874408745",
//       "9573012345",
//    ];
//    TimeStampFileLogger logger = TimeStampFileLogger(path: files[0], duplicate: false);
//
//    group('base',(){
//       test('expect all file exists', (){
//          logger ??= TimeStampFileLogger(path: files[0], duplicate: false);
//          files.forEach((path){
//             File(path).createSync();
//             expect(File(path).existsSync(), isTrue);
//          });
//       });
//
//       test('', () async {
//          /*await logger.ready().then((r){
//             logger.log(key: "read",  data: data[0]);
//             logger.log(key: "write", data: data[0]);
//             logger.log(key: "read",  data: data[0]);
//             expect(logger.logData.length, 2);
//             print(logger.logData);
//          });*/
//       });
//
//       test('', (){
//          data.forEach((d){
//             logger.log(key:"read", data: d);
//             logger.log(key:"write", data: d);
//          });
//          FN.prettyPrint(logger.logData);
//       });
//
//       test('', (){
//          logger.file_sink!.close();
//          final s = File(logger.logPath).readAsStringSync();
//          print(s);
//       });
//    });
// }