import 'dart:io';

import 'package:test/test.dart';
import 'package:IO/src/io.yamlconfig.dart';
import 'package:IO/src/io.path.dart' show Path, getScriptPath;
import 'package:yaml/yaml.dart' show loadYaml;
import 'io.yamlconfig.test.dart' show CURRENT, DATA;
import 'package:IO/src/io.codecs.dart';

final base = '${getScriptPath(Platform.script)}/io_codec_test';


void main() {
   getScriptPath(Platform.script);
   
   final files = [
      '$base/nxp.db.offline.device.json',
      '$base/nxp.db.offline.opt.json',
      '$base/nxp.db.offline.user.json',
      '$base/nxp.db.tag.config-mid-0--201964-1757',
      '$base/nxp.db.tag.config-mid-0-English-201964-1811',
      '$base/nxp.db.tag.config-mid-0-Hyundai-201964-206',
   ];
   group('base',(){
      test('expect all file exists', (){
         files.forEach((path){
            expect(File(path).existsSync(), isTrue);
            
         });
      });
      
      test('decript and encrypt', (){
         files.forEach((path){
               final key = 'knot';
               final origContent = File(path).readAsStringSync();
               final encrypt     = Crypto.encrypt(origContent, key);
               final decrypt     = Crypto.decrypt(encrypt, key);
               print(encrypt);
               print(decrypt);
               expect(origContent, decrypt);
         });
      });

      test('decript and encrypt with compression1', (){
         files.forEach((path){
            final key = 'knot';
            final origContent = Crypto.compress((File(path).readAsStringSync()));
            final encrypt     = Crypto.encrypt(origContent, key);
            final decrypt     = Crypto.decrypt(encrypt, key);
            print(origContent);
            print(decrypt);
            expect(origContent, decrypt);
         });
      });

      test('decript and encrypt with compression2', (){
         files.forEach((path){
            final key = 'knot';
            final origContent = File(path).readAsStringSync();
            final encrypt     = Crypto.compress(origContent, encrypt: true);
            final decrypt     = Crypto.decompress(encrypt, encrypt: true);
            print(origContent);
            print(decrypt);
            expect(origContent, decrypt);
         });
      });
      
      test('write encrypt', (){
         files.forEach((path){
            final key = 'knot';
            final origContent = File(path).readAsStringSync();
            final encrypt     = Crypto.compress(origContent, encrypt: true);
            File(path + '.enc').writeAsStringSync(encrypt);
            final es = File(path + '.enc').readAsStringSync();
            final os = Crypto.decompress(es, encrypt: true);
            
            expect(origContent, os);
            
         });
      });
   });
}