library urls;

import 'package:route/url_pattern.dart';

final defHomeUrl = new UrlPattern(r'/');
final staticFilesUrl = new UrlPattern(r'((.*)(html|txt))');
// More patterns here...

final noAuthUrls = [ defHomeUrl, staticFilesUrl ];
