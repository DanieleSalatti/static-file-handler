library nemserver;

import 'dart:io';
import 'dart:async';
import 'package:path/path.dart';
import 'package:route/server.dart';
import 'package:route/pattern.dart';
import 'package:static_file_handler/static_file_handler.dart';
import 'urls.dart';


class NemServer {

  runServer(String basePath, String ip, int port) {
    StaticFileHandler fileHandler = new StaticFileHandler.serveFolder(basePath);

    HttpServer.bind(ip, port)
      .then((HttpServer server) {
        print("Listening on port: ${server.port}");
        var router = new Router(server)
            // Static files and other stuff that do not require authentication
            ..filter(matchAny(noAuthUrls), noAuth)
            ..serve(defHomeUrl).listen( fileHandler.handleRequest )
            ..serve(staticFilesUrl).listen( fileHandler.handleRequest )
            // More filters and routes here...
            ..defaultStream.listen( fileHandler.handleRequest );

        },
      onError: (error) => print("Error: $error"));
  }

  Future<bool> noAuth(HttpRequest request) {
    return new Future.value(true);
  }

}

main() {
  NemServer nemServer = new NemServer();

  int port = 3200;

  String path = normalize("../www");

  nemServer.runServer(path, "0.0.0.0", port);
}
