dart-static-file-handler
========================

A static file Web server written in Dart.
It can be used as a stand-alone command line tool or imported as a package in a Dart application.

[![Build Status](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/status.png)](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/latest)

Usage
-----

To serve files from a directory:

```shell
bin/static_file_handler.dart <root-path> <port>
```

To import the library as a package in your Dart application:

```dart
StaticFileHandler fileHandler = new StaticFileHandler.serveFolder(basePath);

fileHandler.handleRequest(httpRequest);
```