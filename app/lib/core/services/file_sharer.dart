import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the OS share sheet.
abstract interface class FileSharer {
  /// Writes [bytes] to a temporary file called [fileName] and shares it.
  Future<void> shareBytes(List<int> bytes, String fileName);

  /// Deletes files left behind by earlier [shareBytes] calls, so an export
  /// does not outlive the session that created it.
  Future<void> deleteExports();
}

/// [FileSharer] backed by `path_provider` and `share_plus`.
class SystemFileSharer implements FileSharer {
  /// Creates the sharer.
  const SystemFileSharer();

  @override
  Future<void> shareBytes(List<int> bytes, String fileName) async {
    await deleteExports();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(file.path)]);
  }

  @override
  Future<void> deleteExports() async {
    try {
      final dir = await getTemporaryDirectory();
      await for (final entity in dir.list()) {
        if (entity is File &&
            p.basename(entity.path).startsWith('jobtrail-export-')) {
          await entity.delete();
        }
      }
    } on Object {
      // Temp files are cleaned up by the OS eventually; never block the caller.
    }
  }
}
