# static-file-handler

A static file Web server written in Dart.
It can be used as a stand-alone command line tool or imported as a package in a Dart application.

[![Build Status](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/status.png)](https://drone.io/github.com/DanieleSalatti/dart-static-file-handler/latest)

## Usage

The static-file-handler can be used:

* From the command line to serve files from a directory
* To serve static files while your server side app takes care of all the dynamic requests
* To spawn a Web server and serve static content from your app

### Serve a directory from the command line

To serve files from a directory:

```shell
bin/static_file_handler.dart <root-path> <port>
```

### Serve static files while your server side app takes care of all the dynamic requests

To import the library as a package in your Dart application:

```dart
StaticFileHandler fileHandler = new StaticFileHandler.serveFolder(basePath);

fileHandler.handleRequest(httpRequest);
```

### Spawn a Web server and serve static content from your app

```dart
var fileHandler = new StaticFileHandler(path, port: port);
  
fileHandler.start();
```

## Adding custom MIME types