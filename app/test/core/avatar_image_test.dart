import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jobtrail/core/services/avatar_image.dart';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('avatar_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  String write(String name, List<int> bytes) {
    final f = File('${dir.path}/$name')..writeAsBytesSync(bytes);
    return f.path;
  }

  test('type comes from the content, not the file name', () async {
    final png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 1, 2];
    final jpeg = [0xff, 0xd8, 0xff, 0xe0, 1, 2];

    final a = await prepareAvatarImage(write('photo.jpg', png));
    expect(a.isPng, isTrue);
    expect(a.fileName, 'avatar.png');
    expect(a.subtype, 'png');

    final b = await prepareAvatarImage(write('photo', jpeg));
    expect(b.isPng, isFalse);
    expect(b.fileName, 'avatar.jpg');
    expect(b.subtype, 'jpeg');
  });

  test('something that is not an image is rejected', () async {
    final path = write('notes.jpg', List.filled(32, 7));
    expect(prepareAvatarImage(path), throwsA(isA<FormatException>()));
  });
}
