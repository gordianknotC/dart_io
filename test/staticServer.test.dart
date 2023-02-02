import 'package:IO/src/io.simpleserver.dart';




void main() async {
   final server = FileArchiveStaticServer();
   server.onRequest((req){
   
   });
   await server.start().then((r){
   
   });
}