

import 'package:test/test.dart';
import 'package:IO/src/io.path.dart' show Path;




void main(){
   print(Path.join("/hello/world", "json.text"));
   print(Path.join("/hello/world", "/json/json.text"));
   
   
}