library example;

import 'dart:io';
import 'package:static_file_handler/static_file_handler.dart';

void main() {
  String ip = "0.0.0.0";
  String path = "../www/";
  int port = 3100;
  
  
  var fileHandler = new StaticFileHandler(path, port: port, ip: ip);
  
  fileHandler.start();
}