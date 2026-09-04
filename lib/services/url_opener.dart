import 'url_opener_native.dart'
    if (dart.library.js_interop) 'url_opener_web.dart';

abstract class UrlOpenerInterface {
  void open(String url);
}

class UrlOpener {
  static final UrlOpenerInterface _impl = createUrlOpener();

  static void open(String url) => _impl.open(url);
}
