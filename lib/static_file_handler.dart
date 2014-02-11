library static_file_handler;

import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as path;

class StaticFileHandler {

  HttpServer _server;
  String _root;
  int _port;
  String _ip;
  int _maxAge;

  int get port => _port;
  String get documentRoot => _root;
  String get ip => _ip;
  int get maxAge => _maxAge;
      set maxAge(num value) => _maxAge = (value >= 0) ? value : 0;

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
    
    _root = path.absolute(path.normalize(documentRoot));

    // @todo: check that the IP is valid
    _ip = ip;

    _checkDir();
  }

  /**
   * Only sets the directory to be used as document root.
   */
  StaticFileHandler.serveFolder(String directory) {
    _root = path.absolute(path.normalize(directory));
    _checkDir();
  }

  void _errorHandler(error) {
    // Every error goes here. Add potential logger here.
    print("Error: ${error.toString()}");
  }

  void _checkDir() {
    var dir = new Directory(_root);
    if (!dir.existsSync()) {
      print("Root path does not exist or is not a directory: " + _root);
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
          String name = path.basename(entity.path);
          String href = path.join(request.uri.path, name);
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

    void pipeToResponse(Stream fileContent, HttpResponse response) {
      fileContent.pipe(response).then((_) => response.close()).catchError(_errorHandler);
    }
    
    void _sendRange(File file, HttpResponse response, String range, length) {
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
        response.headers.set(HttpHeaders.CONTENT_RANGE, "bytes $start-${end - 1}/$length");

        // Pipe the 'range' of the file.
        pipeToResponse(file.openRead(start, end), response);
      }
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

        String ext = path.extension(file.path);
        if (_extToContentType.containsKey(ext.toLowerCase())) {
          response.headers.contentType = ContentType.parse(_extToContentType[ext.toLowerCase()]);
        }

        if (request.method == 'HEAD') {
          response.close();
          return;
        }

        // If the Range header was received, handle it.
        String range = request.headers.value("range");
        if (range != null) {
          _sendRange(file, response, range, length);
          return;
        }

        /*
         * Send content length if using HTTP/1.0
         * When using HTTP/1.1 chunked transfer encoding is used
         */
        if (request.protocolVersion == "1.0") {
          response.headers.set(HttpHeaders.CONTENT_LENGTH, length);
        }

        if (_maxAge != null) {
          response.headers.set(HttpHeaders.CACHE_CONTROL, "max-age=$_maxAge");
        }
        
        // Fall back to sending the entire content.
        pipeToResponse(file.openRead(), response);
      }, onError: fileError);
    }, onError: fileError);
  }

  _resolvePath(String uriPath) {
    var decodedUri = Uri.decodeComponent(uriPath);
    var root = path.rootPrefix(decodedUri);
    var parts = path.split(decodedUri);

    if (parts.isNotEmpty && parts.first == root) {
      parts.removeAt(0);
    }

    parts.removeWhere((e) => e.isEmpty);
    String retPath;
    if (!parts.isEmpty) {
      var paths = [];
      paths.add(_root);
      paths.addAll(parts);
      retPath = path.joinAll(paths);
    } else {
        retPath = _root;
    }

    return retPath;
  }

  /**
   * Handles the HttpRequest [request]
   */
  void handleRequest(HttpRequest request) {
    request.response.done.catchError(_errorHandler);

    if (path.split(request.uri.path).contains('..')) {
      // Invalid path.
      request.response.statusCode = HttpStatus.FORBIDDEN;
      request.response.close();
      return;
    }

    String uriPath = _resolvePath(request.uri.path);

    FileSystemEntity.type(uriPath)
    .then((type) {
      switch (type) {
        case FileSystemEntityType.FILE:
          // If file, serve as such.
          _serveFile(new File(uriPath), request);
          break;

        case FileSystemEntityType.DIRECTORY:
          // If directory, serve as such.
          var index = path.join(uriPath, "index.html");
          if (new File(index).existsSync()) {
            _serveFile(new File(index), request);
          } else {
            _serveDir(new Directory(uriPath), request);
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
