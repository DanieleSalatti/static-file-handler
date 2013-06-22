library static_file_handler;

import 'dart:io';
import 'dart:async';
import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:static_file_handler/static_file_handler.dart';

void main() {
  ArgResults args = _getArgs();
  
  if (args != null) {
    
    Map mimeTypes;
    
    String rootPath = args['root'];
    String host = args['host'];

    int port;
    try {
      port = int.parse(args['port']);
    } catch (e) {
      print("Invalid port number");
      exit(-1);
    }
    
    String config = args['config'];
    
    if (config != null) { // At the moment the config file overrides other command line arguments 
      var file = new File(config);
      String configFileContent = file.readAsStringSync(encoding: Encoding.ASCII);
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


ArgResults _getArgs() {

  final argParser = new ArgParser();
  argParser.addOption("config", abbr:"c", help:"Specify a configuration file (see config.yaml)", defaultsTo: null);
  argParser.addOption("host", abbr:"h", help:"Binds the Web server to the specified IP", defaultsTo: "0.0.0.0");
  argParser.addOption("root", abbr:"r", help:"Sets the document root", defaultsTo: "/");  
  argParser.addOption("port", abbr:"p", help:"Sets the port number", defaultsTo: "80");

  final options = new Options();
  if (options.arguments.length == 0) {
    print(argParser.getUsage());
    return null;
  }
  else {
    return argParser.parse(options.arguments);
  }
}