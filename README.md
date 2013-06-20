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

You can serve files from a directory by running the Dart script located into `bin`:

```shell
cd static_file_handler/bin
dart static_file_handler.dart <root-path> <port>
```

### Serve static files from your server app

Add the package to your pubspec.yaml file:

```yaml
dependencies:
  static_file_handler: any
```

Create an instance of the static file handler using the named constructor `serveFolder(String directory)`, then call `handleRequest(HttpRequest request)` to serve your files. In this way your server application can handle all the dynamic requests, and you won't have to take care of the static files.

```dart
StaticFileHandler fileHandler = new StaticFileHandler.serveFolder("/path/to/folder");

fileHandler.handleRequest(httpRequest);
```
You can see an example that uses the `route` package in the `example/handle_request` folder.

### Spawn a Web server and serve static content from your app

If your command line application needs to serve static files (but it's not a server), you can do as follows:

```dart
var fileHandler = new StaticFileHandler(path, port: port);
  
fileHandler.start();
```

## Adding custom MIME types