import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the OS share sheet.
abstract interface class FileSharer {
  /// Writes [bytes] to a temporary file called [fileName] and shares it.
  Future<void> shareBytes(List<int> bytes, String fileName);
}

/// [FileSharer] backed by `path_provider` and `share_plus`.
class SystemFileSharer implements FileSharer {
  /// Creates the sharer.
  const SystemFileSharer();

  @override
  Future<void> shareBytes(List<int> bytes, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }
}
