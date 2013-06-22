library static_file_handler;

import 'dart:io';
import 'dart:async';
import 'package:yaml/yaml.dart';
import 'package:static_file_handler/static_file_handler.dart';

void printUsage(String script) {
  print("Usage: ${script} -d <root-path> -p <port>");
  print("");
  print("Accepted parameters:");
  print("\t-b <ip>\t\t\tBinds the Web server to the specified <ip>");
  print("\t-c <file>\t\tUses the configuration file <file>");
  print("\t\t\t\tIf the same option is specified both as a command line argument");
  print("\t\t\t\tand into the config file, the config file will prevail");
  print("\t-d <root-path>\t\tSets the document root to <root-path>");
  print("\t-h --help\t\tShows this help");
  print("\t-p <port>\t\tSets the port number to <port>");
}

void main() {
  Options options = new Options();
  
  var args = options.arguments;
  
  String path = './';
  int port = 80;
  String configFile;
  String ip = '0.0.0.0';
  Map mimeTypes;
  
  for (int i = 0; i < args.length; i+=2) {
    
    switch(args[i]) {
      
      case "-b":  // IP
        ip = args[i+1];
        break;
        
      case "-c":  // use config file
        configFile = args[i+1];
        break;
        
      case "-d":  // document root
        path = args[i+1];
        break;
        
      case "-h":  // help
      case "--help":
        printUsage(options.script);
        exit(0);
        break;
        
      case "-p":  // port
        try {
          port = int.parse(args[i+1]);
        } catch (e) {
          print("Invalid port");
          printUsage(options.script);
          exit(-1);
        }
        break;
        
      default:
        print("Invalid argument");
        printUsage(options.script);
        exit(-1);
        break;
    }  
    
  }

  if (configFile != null) { // At the moment the config file overrides other command line arguments 
    var file = new File(configFile);
    String configFileContent = file.readAsStringSync(encoding: Encoding.ASCII);
    YamlMap config = loadYaml(configFileContent);
    
    if (config['ip'] != null) {
      ip = config['ip'];
    }
    if (config['port'] != null) {
      port = config['port'];
    }
    if (config['document-root'] != null) {
      path = config['document-root'];
    }
    if (config['mime-types'] != null) {
      mimeTypes = config['mime-types'];
    }
  }
  
  var fileHandler = new StaticFileHandler(path, port: port, ip: ip);
  
  if (mimeTypes != null) {
    fileHandler.addMIMETypes(mimeTypes);
  }
  
  fileHandler.start();
}