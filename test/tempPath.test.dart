

import 'package:test/test.dart';
import 'package:dart_io/src/io.path.dart' show Path;




void main(){
   print(Path.join("/hello/world", "json.text"));
   print(Path.join("/hello/world", "/json/json.text"));
   
   
}