library staticFileHandlerTest;

import 'package:unittest/unittest.dart';
import 'dart:async';
import 'dart:io';

import 'package:dart_static_file_handler/static_file_handler.dart';



main() {
  
  StaticFileHandler fileHandler;
  int port = 3500;
  String directory = './www';
  HttpClient client = new HttpClient();
  
  group('Server', () {
    
    setUp(() {
      fileHandler = new StaticFileHandler(directory, port:port);
      return fileHandler.serve();
    });
    
    tearDown(() {
      fileHandler.stop();
    });
    
    test('Port is properly set', () {
      expect(fileHandler.port, equals(port));
    });
    
    test('Simple GET Request', () {
      Completer<bool> completer = new Completer();
      String finalString = "";
      
      client.get("127.0.0.1", port, "/").then((HttpClientRequest request) {
        return request.close();

      }).then((HttpClientResponse response) {
        expect(response.statusCode, equals(HttpStatus.OK));
        completer.complete(true);
      });
      
      return completer.future;
    });
    
    test('File not found', () {
      Completer<bool> completer = new Completer();
      String finalString = "";
      
      client.get("127.0.0.1", port, "/nonexistentfile.html").then((HttpClientRequest request) {
        return request.close();

      }).then((HttpClientResponse response) {
        expect(response.statusCode, equals(HttpStatus.NOT_FOUND));
        completer.complete(true);
      });

      return completer.future;
    });
    
    test('Serving file', () {
      Completer<bool> completer = new Completer();
      String finalString = "";
      
      client.get("127.0.0.1", port, "/textfile.txt").then((HttpClientRequest request) {
        return request.close();

      }).then((HttpClientResponse response) {
        response.transform(new StringDecoder())
        .transform(new LineTransformer())
        .listen((String result) {
          finalString += result;
        },
        onDone: () {
          expect(finalString, equals("test"));
          completer.complete(true);
        });
      });

      return completer.future;
    });
    
  }); 
  
}
