import 'dart:convert';
import 'dart:async' show Future;
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:tripledes/tripledes.dart';
import 'package:path/path.dart' as Path;
import 'package:dart_io/src/io.path.dart';


const BASE_KEY = 'crypto';
const DATA_URI_PREFIX = "data:image/png;base64,";

/// 載入 image 並可轉換為 datauri | bytes
/// [getPath] 取得 absolute path
/// [loadAsync] load image in async way
/// [loadSync] load image in sync way
/// [datauri] 取得 image datauri
///
/// __example:__
/// ```dart
/// Img.loadAsync('./assets/newsicon.png').then((image) {
///   print('image.path: ${image.path}');
///   print('image.bytes: ${image.bytes}');
///   print('image.uri: ${image.datauri}');
/// });; 
/// ```
/// 
class Img {
   String path;
   Uri uri;
   Img(this.path, this.uri);
    static String getPath(String pth) {
      return Path.join(getScriptPath(Platform.script), pth);
   }
   
   static Future<Img> loadAsync(String pth) {
      final path = Img.getPath(pth);;
      return File(path).readAsBytes().then((data) {
         final uri = Uri.dataFromBytes(data);
         return Img(path, uri);
      });
   }
   
   static Img loadSync(String pth) {
      final path = pth = Img.getPath(pth);
      final uri = Uri.dataFromBytes(File(path).readAsBytesSync());
      return Img(path, uri);
   }

   String get datauri {
      return DATA_URI_PREFIX + (uri.data?.contentText ?? "");
   }
   
   Uint8List get bytes {
      return uri.data?.contentAsBytes.call() ?? Uint8List(0);
   }
   
   void dumpAsText() {
      var base = Path.basename(path + '.txt');
      var dir = Path.dirname(path);
      File(Path.join(base, dir)).writeAsStringSync((uri.data?.contentText ?? ""));
   }
}

const DEFAULT_ENCRYPT_KEY = 'XYZDefault';

/// 1) 以 [BlockCipher] 加密解密
/// 2) 加密後壓縮 | 解壓縮後解密
class Crypto {
   static List<int>
   toBytes(String source) {
      return utf8.encode(source);
   }
   
   static XtoY(Encoding x, Codec y, String source){
      return x.fuse(y as dynamic).encode(source);
   }
   static String
   utf8ToBase64(String source) {
      return utf8.fuse(base64).encode(source);
   }
   
   static String
   base64ToUtf8(String source) {
      return utf8.fuse(base64).decode(source);
   }
   
   static String compress(String source, {bool encrypt = false}) {
      List<int> gzip_bytes, string_bytes;
      string_bytes = utf8.encode(source);
      gzip_bytes = GZipEncoder().encode(string_bytes);
      if (!encrypt)
         return base64.encode(gzip_bytes);
      return Crypto.encrypt(base64.encode(gzip_bytes), DEFAULT_ENCRYPT_KEY);
   }
   
   static String decompress(String source, {bool encrypt = false}) {
      /* Every human readable text in Dart, which is user typed/copied text or any text
         show-up on screen, is utf8 by default. For preventing FormatException, which
         is encode/decode error, convert string from utf8 to base64 for any text needs
         to be decode into base64 bytes is necessary.*/
      if (encrypt)
         source = Crypto.decrypt(source, DEFAULT_ENCRYPT_KEY);
      
      List<int> gzip_bytes, string_bytes;
      try{
         gzip_bytes = base64.decode(source);
      }on FormatException{
         gzip_bytes = base64.decode(Crypto.utf8ToBase64(source));
      }
      string_bytes   = GZipDecoder().decodeBytes(gzip_bytes);
      return utf8.decode(string_bytes);
   }
   
   static encrypt(String source, String key) {
      var blockCipher = BlockCipher(DESEngine(), Crypto.getCryptoKey(key));
      return blockCipher.encodeB64(Crypto.utf8ToBase64(source));
   }
   
   static String decrypt(String source, String key) {
      var blockCipher = BlockCipher(DESEngine(), Crypto.getCryptoKey(key));
      return Crypto.base64ToUtf8(blockCipher.decodeB64(source));
   }
   
   static getCryptoKey(String name) {
      var blockCipher = BlockCipher(DESEngine(), BASE_KEY);
      return blockCipher.encodeB64(name);
   }
}

void main([arguments]) {
   final _source = 'zBKfqq7N31dUAMno9t7W4AhKJFccT4J8rHkmYxuLeCPscdmOwUnSxqt5fj';
   final SOURCE  = Crypto.decrypt(Crypto.decompress(_source), "gordianknot");
   if (arguments.length == 1 && arguments[0] == '-directRun') {
      var source = SOURCE;
      print('source: $source');
      var compressed = Crypto.compress(source);
      print('compressed: $compressed');
      var decomp = Crypto.decompress(compressed);
      print('decompressed: $decomp');

      var encrypted = Crypto.encrypt(source, "gordianknot");
      print('encrypted: $encrypted');
      var decrypted = Crypto.decrypt(encrypted, 'gordianknot');
      print('decrypted: $decrypted');
      
      print('SOURCE: $SOURCE');
      var encrypted2 = Crypto.compress(Crypto.encrypt(SOURCE, "gordianknot"));
      print('encrypted2:\n\t$encrypted2');
      var decrypted2 = Crypto.decrypt(Crypto.decompress(encrypted2), "gordianknot");
      print('decrypted2:\n\t$decrypted2');

      var base64 = 'QXdlc29tZSE=';
      var utf8 = 'Awesome!';
      print('\nbase64 to utf8: ${Crypto.base64ToUtf8(base64)}');
      print('utf8 to base64: ${Crypto.utf8ToBase64(utf8)}');
      
      Img.loadAsync('./assets/newsicon.png').then((image) {
         print('image.path: ${image.path}');
         print('image.bytes: ${image.bytes}');
         print('image.uri: ${image.datauri}');
      });
   }
}
