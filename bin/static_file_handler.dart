//COMPLETELY UNTESTED, USE AT YOUR OWN RISK

//Licensed under BSD: https://code.google.com/google_bsd_license.html

import 'dart:io';


const EXT_TO_CONTENT_TYPE = const {
    "txt": "text/plain; charset=utf-8",  // Assumes UTF-8 files.
    "json": "application/json",
    "webm": "video/webm",
    "mp4": "video/mp4",
    "html": "text/html; charset=utf-8",  // Assumes UTF-8 files.
    "png": "image/png",
    "jpg": "image/jpeg" };


void errorHandler(error) {
  // Every error goes here. Add potential logger here.
}


/**
 * Serve the directory [dir] to the [request]. The content of the directory
 * will be listed in bullet-form, with a link to each element.
 */
void serveDir(Directory dir, HttpRequest request) {
  var response = request.response;

  response.write("<html><head>");
  response.write("<title>${request.uri}</title>");
  response.write("</head><body>");
  response.write("<h1>Contents of ${request.uri}</h1><ul>");

  dir.list().listen(
      (entity) {
        var name = new Path(entity.path).filename;
        var href = new Path(request.uri.path).append(name);
        response.write("<li><a href='$href'>$name</a></li>");
      },
      onDone: () {
        response.write("</ul></body></html>");
        response.close();
      },
      onError: errorHandler);
}


/**
 * Serve the file [file] to the [request]. The content of the file will be
 * streamed to the response. If a supported [:Range:] header is received, only
 * a smaller part of the [file] will be streamed.
 */
void serveFile(File file, HttpRequest request) {
  var response = request.response;

  // Callback used if file operations fails.
  void fileError(e) {
    response.statusCode = 404;
    response.close();
    errorHandler(e);
  }

  file.lastModified().then((lastModified) {
    // If If-Modified-Since is present and file haven't changed, return 304.
    if (request.headers.ifModifiedSince != null &&
        !lastModified.isAfter(request.headers.ifModifiedSince)) {
      response.statusCode = 304;
      response.close();
      return;
    }


    file.length().then((length) {
      // Always set Accept-Ranges and Last-Modified headers.
      response.headers.set(HttpHeaders.ACCEPT_RANGES, "bytes");
      response.headers.set(HttpHeaders.LAST_MODIFIED, lastModified);

      var ext = new Path(file.path).extension;
      if (EXT_TO_CONTENT_TYPE.containsKey(ext)) {
        response.headers.contentType =
            ContentType.parse(EXT_TO_CONTENT_TYPE[ext]);
      }

      if (request.method == 'HEAD') {
        response.close();
        return;
      }

      // If the Range header was received, handle it.
      var range = request.headers.value("range");
      if (range != null) {
        // We only support one range, where the standard support several.
        var matches = new RegExp(r"^bytes=(\d*)\-(\d*)$").firstMatch(range);
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
          response.statusCode = 206;
          response.headers.set(HttpHeaders.CONTENT_RANGE,
                               "bytes $start-${end - 1}/$length");

          // Pipe the 'range' of the file.
          file.openRead(start, end).pipe(response)
              .catchError(errorHandler);
          return;
        }
      }
      // Fall back to sending the entire content.
      file.openRead().pipe(response).catchError(errorHandler);
    }, onError: fileError);
  }, onError: fileError);
}

void main() {
  var options = new Options();

  if (options.arguments.length != 2) {
    print("Usage: ${options.script} <root-path> <port>");
    exit(-1);
  }

  var root = new Path(options.arguments[0]).canonicalize();
  if (!new Directory.fromPath(root).existsSync()) {
    print("Root path does not exist or is not a directory");
    exit(-1);
  }

  int port;
  try {
    port = int.parse(options.arguments[1]);
  } catch (e) {
    print("Bad port format");
    exit(-1);
  }

  // Start the HttpServer.
  HttpServer.bind("0.0.0.0", port)
      .then((server) {
        server.listen((request) {
          request.listen(
              (_) { /* ignore post body */ },
              onDone: () {
                request.response.done.catchError(errorHandler);

                if (new Path(request.uri.path).segments().contains('..')) {
                  // Invalid path.
                  request.response.statusCode = 403;
                  request.response.close();
                  return;
                }

                var path = root.append(request.uri.path).canonicalize();

                FileSystemEntity.type(path.toString())
                    .then((type) {
                      switch (type) {
                        case FileSystemEntityType.FILE:
                          // If file, serve as such.
                          serveFile(new File.fromPath(path), request);
                          break;

                        case FileSystemEntityType.DIRECTORY:
                          // If directory, serve as such.
                          serveDir(new Directory.fromPath(path), request);
                          break;

                        default:
                          // File not found, fall back to 404.
                          request.response.statusCode = 404;
                          request.response.write("File not found");
                          request.response.close();
                          break;
                      }
                    });
              },
              onError: errorHandler,
              cancelOnError: true);
        }, onError: errorHandler);
      });
}

