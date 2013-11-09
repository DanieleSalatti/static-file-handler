library static_file_handler;

import 'dart:io';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:static_file_handler/static_file_handler.dart';

final argParser = new ArgParser();

void main(List<String> arguments) {
  ArgResults args = _getArgs(arguments);
  
  if (args != null) {
    
    if (args['help']) {
      print(argParser.getUsage());
      exit(0);
    }
    
    Map mimeTypes;
    
    String config = args['config'];
    String rootPath = args['root'];
    String host = args['host'];

    int port;
    try {
      port = int.parse(args['port']);
    } catch (e) {
      print("Invalid port number");
      exit(-1);
    }
    
    if (config != null) { // At the moment the config file overrides other command line arguments 
      var file = new File(config);
      String configFileContent = file.readAsStringSync(encoding: Encoding.getByName("ASCII"));
      YamlMap configFile = loadYaml(configFileContent);
      
      if (configFile['host'] != null) {
        host = configFile['host'];
      }
      if (configFile['port'] != null) {
        port = configFile['port'];
      }
      if (configFile['document-root'] != null) {
        rootPath = configFile['document-root'];
      }
      if (configFile['mime-types'] != null) {
        mimeTypes = configFile['mime-types'];
      }
    }
    
    var fileHandler = new StaticFileHandler(rootPath, port: port, ip: host);
    
    if (mimeTypes != null) {
      fileHandler.addMIMETypes(mimeTypes);
    }
    
    fileHandler.start();
  }
}


ArgResults _getArgs(List<String> arguments) {

  argParser.addOption("config", abbr:"c", help:"Specify a configuration file (see config.yaml)", defaultsTo: null);
  argParser.addOption("host", abbr:"h", help:"Binds the Web server to the specified IP", defaultsTo: "0.0.0.0");
  argParser.addFlag("help", help:"Shows this help", negatable:false);
  argParser.addOption("root", abbr:"r", help:"Sets the document root", defaultsTo: "/");  
  argParser.addOption("port", abbr:"p", help:"Sets the port number", defaultsTo: "3000");
  
  return argParser.parse(arguments);
}