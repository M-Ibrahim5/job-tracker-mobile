import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// An image the API accepts: JPEG or PNG bytes within the size limit.
class AvatarImage {
  /// Creates an image of [bytes] with the matching [isPng] type.
  const AvatarImage(this.bytes, {required this.isPng});

  final Uint8List bytes;
  final bool isPng;

  /// File name and MIME subtype sent in the multipart part.
  String get fileName => isPng ? 'avatar.png' : 'avatar.jpg';
  String get subtype => isPng ? 'png' : 'jpeg';
}

/// Server limit for `POST /me/avatar` (`API.md`).
const avatarMaxBytes = 2 * 1024 * 1024;

/// True when [b] starts with the PNG signature.
bool isPngBytes(List<int> b) =>
    b.length >= 4 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4e &&
    b[3] == 0x47;

/// True when [b] starts with the JPEG signature.
bool isJpegBytes(List<int> b) => b.length >= 2 && b[0] == 0xff && b[1] == 0xd8;

/// Reads the image at [path] and returns it in a form the API accepts.
///
/// The type is decided from the file's content, not its extension: gallery
/// pickers can hand back a `.jpg`-named WebP/HEIC or a PNG with no extension,
/// which the server (rightly) rejects. Anything that is not already a
/// JPEG/PNG under [avatarMaxBytes] is decoded and re-encoded as PNG, shrinking
/// until it fits. Throws [FormatException] if the file is not a decodable image.
Future<AvatarImage> prepareAvatarImage(String path) async {
  final bytes = await File(path).readAsBytes();
  final png = isPngBytes(bytes);
  if ((png || isJpegBytes(bytes)) && bytes.length <= avatarMaxBytes) {
    return AvatarImage(bytes, isPng: png);
  }
  for (final width in const [1024, 768, 512, 256]) {
    final out = await _reencodeAsPng(bytes, width);
    if (out.length <= avatarMaxBytes) return AvatarImage(out, isPng: true);
  }
  throw const FormatException('Image is too large');
}

Future<Uint8List> _reencodeAsPng(Uint8List bytes, int maxWidth) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data!.buffer.asUint8List();
  } on Exception {
    throw const FormatException('Not a supported image');
  }
}
