// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Web-only: builds a Blob from `bytes` and clicks a hidden anchor so the
/// browser downloads the file with the given name.
Future<void> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final blob = html.Blob(<dynamic>[bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Free the object URL after a tick so the click has a chance to fire.
  await Future<void>.delayed(const Duration(milliseconds: 50));
  html.Url.revokeObjectUrl(url);
}
