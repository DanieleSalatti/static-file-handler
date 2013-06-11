//COMPLETELY UNTESTED, USE AT YOUR OWN RISK

//Licensed under BSD: https://code.google.com/google_bsd_license.html

import 'dart:io';

class StaticFileHandler {
  
  Path _root;
  int _port;
  
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
   * This constructor is to be used when running the static file handler as a standalone app.
   */
  StaticFileHandler(String directory, {int port: 80}) {
    // If port == 0 the OS will pick a random available port for us
    if (65535 < port || 0 > port ) {
      print("Invalid port");
      exit(-1);
    }
    
    _port = port;
    
    _root = new Path(directory).canonicalize();
    
    checkDir();
  }
  
  /**
   * This named constructor is to be used when using the static file handler within another
   * Dart script.
   */
  StaticFileHandler.serveFolder(directory) {
    _root = new Path(directory).canonicalize();
    checkDir();
  }

  void errorHandler(error) {
    // Every error goes here. Add potential logger here.
  }

  void checkDir() {
    if (!new Directory.fromPath(_root).existsSync()) {
      print("Root path does not exist or is not a directory");
      exit(-1);
    }
  }
  
  /**
   * Serve the directory [dir] to the [request]. The content of the directory
   * will be listed in bullet-form, with a link to each element.
   */
  void serveDir(Directory dir, HttpRequest request) {
    HttpResponse response = request.response;
  
    response.write("<html><head>");
    response.write("<title>${request.uri}</title>");
    response.write("</head><body>");
    response.write("<h1>Contents of ${request.uri}</h1><ul>");
  
    dir.list().listen(
        (entity) {
          String name = new Path(entity.path).filename;
          Path href = new Path(request.uri.path).append(name);
          response.write("<li><a href='$href'>$name</a></li>");
        },
        onDone: () {
          response.write("</ul></body></html>");
          response.close();
        },
        onError: errorHandler);
  }
  
  /**
   * Add the MIME types [types] to the list of supported MIME types
   */
  void addMIMETypes(Map<String, String> types){
    types.forEach((key, value) {
      _extToContentType[key] = value;
    });
  }
  
  /**
   * Serve the file [file] to the [request]. The content of the file will be
   * streamed to the response. If a supported [:Range:] header is received, only
   * a smaller part of the [file] will be streamed.
   */
  void serveFile(File file, HttpRequest request) {
    HttpResponse response = request.response;
  
    // Callback used if file operations fails.
    void fileError(e) {
      response.statusCode = HttpStatus.NOT_FOUND;
      response.close();
      errorHandler(e);
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
        
        String ext = new Path(file.path).extension;
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
                .catchError(errorHandler);
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
        file.openRead().pipe(response).catchError(errorHandler);
      }, onError: fileError);
    }, onError: fileError);
  }
  
  void handleRequest(HttpRequest request) {
    request.response.done.catchError(errorHandler);
    
    if (new Path(request.uri.path).segments().contains('..')) {
      // Invalid path.
      request.response.statusCode = HttpStatus.FORBIDDEN;
      request.response.close();
      return;
    }
    
    Path path = _root.append(Uri.decodeComponent(request.uri.path)).canonicalize();
    
    FileSystemEntity.type(path.toString())
    .then((type) {
      switch (type) {
        case FileSystemEntityType.FILE:
          // If file, serve as such.
          serveFile(new File.fromPath(path), request);
          break;
          
        case FileSystemEntityType.DIRECTORY:
          // If directory, serve as such.
          if (new File.fromPath(path.append("index.html")).existsSync()) {
            serveFile(new File.fromPath(path.append("index.html")), request);
          } else {
            serveDir(new Directory.fromPath(path), request);
          }
          break;
          
        default:
          // File not found, fall back to 404.
          request.response.statusCode = HttpStatus.NOT_FOUND;
          request.response.write("File not found");
          request.response.close();
          break;
      }
    });
  }
  
  /**
   * Start the HttpServer
   */
  void serve() {
  
    // Start the HttpServer.
    HttpServer.bind("0.0.0.0", this._port)
        .then((server) {
          print ("Listening on port ${server.port}");
          server.listen((request) {
            request.listen(
                (_) { /* ignore post body */ },
                onDone: handleRequest(request),
                onError: errorHandler,
                cancelOnError: true);
          }, onError: errorHandler);
        });
  }
}
