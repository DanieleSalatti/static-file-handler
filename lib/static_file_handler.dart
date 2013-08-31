library static_file_handler;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart';

class StaticFileHandler {

  HttpServer _server;
  Builder _root;
  int _port;
  String _ip;

  int get port => _port;
  String get documentRoot => _root.root;
  String get ip => _ip;

  final _extToContentType = {
    "bz"      : "application/x-bzip",
    "bz2"     : "application/x-bzip2",
    "dart"    : "application/dart",
    "exe"     : "application/octet-stream",
    "gif"     : "image/gif",
    "gz"      : "application/x-gzip",
    "html"    : "text/html; charset=utf-8",  // Assumes UTF-8 files.
    "jpg"     : "image/jpeg",
    "js"      : "application/javascript",
    "json"    : "application/json",
    "mp3"     : "audio/mpeg",
    "mp4"     : "video/mp4",
    "pdf"     : "application/pdf",
    "png"     : "image/png",
    "tar.gz"  : "application/x-tar",
    "tgz"     : "application/x-tar",
    "txt"     : "text/plain; charset=utf-8",  // Assumes UTF-8 files.
    "webp"    : "image/webp",
    "webm"    : "video/webm",
    "zip"     : "application/zip"
  };

  /**
   * Default constructor.
   */
  StaticFileHandler(String documentRoot, {int port: 80, String ip: '0.0.0.0'}) {
    // If port == 0 the OS will pick a random available port for us
    if (65535 < port || 0 > port ) {
      print("Invalid port");
      exit(-1);
    }

    _port = port;

    _root = new Builder(root: absolute(normalize(documentRoot)));

    // @todo: check that the IP is valid
    _ip = ip;

    _checkDir();
  }

  /**
   * Only sets the directory to be used as document root.
   */
  StaticFileHandler.serveFolder(String directory) {
    _root = new Builder(root:  absolute(normalize(directory)));
    _checkDir();
  }

  void _errorHandler(error) {
    // Every error goes here. Add potential logger here.
    print("Error: ${error.toString()}");
  }

  void _checkDir() {
    var dir = new Directory(_root.root);
    if (!dir.existsSync()) {
      print("Root path does not exist or is not a directory");
      exit(-1);
    }
  }

  /**
   * Serve the directory [dir] to the [request]. The content of the directory
   * will be listed in bullet-form, with a link to each element.
   */
  void _serveDir(Directory dir, HttpRequest request) {
    HttpResponse response = request.response;

    response.write("<html><head>");
    response.write("<title>${request.uri}</title>");
    response.write("</head><body>");
    response.write("<h1>Contents of ${request.uri}</h1><ul>");

    dir.list().listen(
        (entity) {
          String name = basename(entity.path);
          Builder hrefBuilder = new Builder(root: request.uri.path);
          String href = hrefBuilder.join(name);
          //Path href = new Path(request.uri.path).append(name);
          response.write("<li><a href='$href'>$name</a></li>");
        },
        onDone: () {
          response.write("</ul></body></html>");
          response.close();
        },
        onError: _errorHandler);
  }

  /**
   * Add the MIME types [types] to the list of supported MIME types
   */
  void addMIMETypes(Map<String, String> types){
    _extToContentType.addAll(types);
  }

  /**
   * Serve the file [file] to the [request]. The content of the file will be
   * streamed to the response. If a supported [:Range:] header is received, only
   * a smaller part of the [file] will be streamed.
   */
  void _serveFile(File file, HttpRequest request) {
    HttpResponse response = request.response;

    // Callback used if file operations fails.
    void fileError(e) {
      response.statusCode = HttpStatus.NOT_FOUND;
      response.close();
      _errorHandler(e);
    }

    file.lastModified().then((lastModified) {
      // If If-Modified-Since is present and file haven't changed, return 304.
      if (request.headers.ifModifiedSince != null &&
          !lastModified.isAfter(request.headers.ifModifiedSince)) {
        response.statusCode = HttpStatus.NOT_MODIFIED;
        response.close();
        return;
      }


      file.length().then((length) {
        // Always set Accept-Ranges and Last-Modified headers.
        response.headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
        response.headers.set(HttpHeaders.LAST_MODIFIED, lastModified);

        String ext = extension(file.path);
        if (_extToContentType.containsKey(ext)) {
          response.headers.contentType =
              ContentType.parse(_extToContentType[ext]);
        }

        if (request.method == 'HEAD') {
          response.close();
          return;
        }

        // If the Range header was received, handle it.
        String range = request.headers.value("range");
        if (range != null) {
          // We only support one range, where the standard support several.
          Match matches = new RegExp(r"^bytes=(\d*)\-(\d*)$").firstMatch(range);
          // If the range header have the right format, handle it.
          if (matches != null) {
            // Serve sub-range.
            int start;
            int end;
            if (matches[1].isEmpty) {
              start = matches[2].isEmpty ? length : length - int.parse(matches[2]);
              end = length;
            } else {
              start = int.parse(matches[1]);
              end = matches[2].isEmpty ? length : int.parse(matches[2]) + 1;
            }

            // Override Content-Length with the actual bytes sent.
            response.headers.set(HttpHeaders.CONTENT_LENGTH, end - start);

            // Set 'Partial Content' status code.
            response.statusCode = HttpStatus.PARTIAL_CONTENT;
            response.headers.set(HttpHeaders.CONTENT_RANGE,
                                 "bytes $start-${end - 1}/$length");

            // Pipe the 'range' of the file.
            file.openRead(start, end).pipe(response)
                .catchError(_errorHandler);
            return;
          }
        }

        /*
         * Send content length if using HTTP/1.0
         * When using HTTP/1.1 chunked transfer encoding is used
         */
        if (request.protocolVersion == "1.0") {
          response.headers.set(HttpHeaders.CONTENT_LENGTH, length);
        }

        // Fall back to sending the entire content.
        file.openRead().pipe(response).catchError(_errorHandler);
      }, onError: fileError);
    }, onError: fileError);
  }

  _resolvePath(String uriPath) {
    Builder builder = new Builder(root: absolute(_root.root));
    var decodedUri = Uri.decodeComponent(uriPath);
    var root = rootPrefix(decodedUri);
    var parts = split(decodedUri);

    if (parts.first == root) {
      parts.removeAt(0);
    }

    parts.removeWhere((e) => e.isEmpty);
    String path;
    if (!parts.isEmpty) {
      var paths = [];
      paths.add(builder.root);
      paths.addAll(parts);
      path = joinAll(paths);
    } else {
      path = builder.root;
    }

    return path;
  }

  /**
   * Handles the HttpRequest [request]
   */
  void handleRequest(HttpRequest request) {
    request.response.done.catchError(_errorHandler);

    if (split(request.uri.path).contains('..')) {
      // Invalid path.
      request.response.statusCode = HttpStatus.FORBIDDEN;
      request.response.close();
      return;
    }

    String path = _resolvePath(request.uri.path);

    FileSystemEntity.type(path)
    .then((type) {
      switch (type) {
        case FileSystemEntityType.FILE:
          // If file, serve as such.
          _serveFile(new File(path), request);
          break;

        case FileSystemEntityType.DIRECTORY:
          // If directory, serve as such.
          path = join(path, "index.html");
          if (new File(path).existsSync()) {
            _serveFile(new File(path), request);
          } else {
            _serveDir(new Directory(path), request);
          }
          break;

        default:
          // File not found, fall back to 404.
          request.response.statusCode = HttpStatus.NOT_FOUND;
          request.response.close();
          break;
      }
    });
  }

  /**
   * Start the HttpServer
   */
  Future<bool> start() {
    var completer = new Completer();
    // Start the HttpServer.
    HttpServer.bind(_ip, _port)
        .then((server) {
          _server = server;
          print ("Listening on port ${_server.port}");
          _server.listen((request) {
            request.listen(
                (_) { /* ignore post body */ },
                onDone: handleRequest(request),
                onError: _errorHandler,
                cancelOnError: true);
          }, onError: _errorHandler);
          completer.complete(true);
        }).catchError(_errorHandler);
    return completer.future;
  }

  /**
   * Stop the HttpServer
   */
  void stop() {
    print("Stop");
    _server.close();
  }
}
