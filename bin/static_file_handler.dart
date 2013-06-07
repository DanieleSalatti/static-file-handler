library static_file_handler;

import 'dart:io';
import 'package:dart_static_file_handler/static_file_handler.dart';

void main() {
  Options options = new Options();

  if (options.arguments.length != 2) {
    print("Usage: ${options.script} <root-path> <port>");
    exit(-1);
  }
  
  String path = options.arguments[0];
  String port = options.arguments[1];
  
  var fileHandler = new StaticFileHandler(path, port: port);
  
  fileHandler.serve();
}