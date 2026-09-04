// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'url_opener.dart';

UrlOpenerInterface createUrlOpener() => _WebUrlOpener();

class _WebUrlOpener implements UrlOpenerInterface {
  @override
  void open(String url) {
    html.window.open(url, '_blank');
  }
}
