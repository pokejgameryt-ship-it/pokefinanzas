import 'package:url_launcher/url_launcher.dart';
import 'url_opener.dart';

UrlOpenerInterface createUrlOpener() => _NativeUrlOpener();

class _NativeUrlOpener implements UrlOpenerInterface {
  @override
  void open(String url) {
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
