import 'package:dart_io/src/io.simpleserver.dart';




void main() async {
   final server = FileArchiveStaticServer();
   server.onRequest((req){
   
   });
   await server.start().then((r){
   
   });
}