dart-static-file-handler
========================

A static file Web server written in Dart.
It can be used as a stand-alone command line tool or imported as a package in a Dart application.

Usage
-----

To serve files from a directory:

```shell
bin/static_file_handler.dart <root-path> <port>
```

To import the library as a package in your Dart application:

```dart
StaticFileHandler fileHandler = new StaticFileHandler(basePath, port:"3500");

fileHandler.handleRequest(httpRequest);
```