import 'dart:typed_data';

/// Native-platform stub. The registers download flow is web-only for now;
/// on desktop/mobile this would need `path_provider` + `share_plus` instead.
Future<void> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  throw UnsupportedError(
    'downloadBytes is web-only. Use share_plus or path_provider on native.',
  );
}
