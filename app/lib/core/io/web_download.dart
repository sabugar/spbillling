/// Cross-platform "save these bytes to disk" helper.
/// Web → triggers a browser blob download; native → currently a no-op
/// (the registers are a web-only flow today).
export 'web_download_stub.dart' if (dart.library.html) 'web_download_html.dart';
