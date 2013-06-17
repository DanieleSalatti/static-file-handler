dart-static-file-handler
========================

A static file Web server written in Dart.
It can be used as a stand-alone command line tool or imported as a package in a Dart application.

[![Build Status](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/status.png)](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/latest)

Usage
-----

To serve files from a directory:

```shell
bin/static_file_handler.dart -d <root-path> -p <port> -c <ip>
```
Accepted parameters:
-b    <ip>        Binds the Web server to the specified <ip>
-c    <file>      Uses the configuration file <file>
                  If the same option is specified both as a command line argument
                  and into the config file, the config file will prevail
-d    <root-path> Sets the document root to <root-path>
-h --help         Shows the help
-p    <port>      Sets the port number to <port>

To import the library as a package in your Dart application:

```dart
StaticFileHandler fileHandler = new StaticFileHandler.serveFolder(basePath);

fileHandler.handleRequest(httpRequest);
```