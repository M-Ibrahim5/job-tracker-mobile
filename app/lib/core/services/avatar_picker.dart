import 'package:image_picker/image_picker.dart';

/// Lets the user choose a profile photo.
abstract interface class AvatarPicker {
  /// Returns the path of the chosen image (downscaled to ≤ 1024px), or null if
  /// the user cancelled.
  Future<String?> pick();
}

/// [AvatarPicker] using the gallery via `image_picker`.
class GalleryAvatarPicker implements AvatarPicker {
  /// Creates the picker.
  const GalleryAvatarPicker();

  @override
  Future<String?> pick() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.path;
  }
}
