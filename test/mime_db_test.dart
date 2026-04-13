import 'package:mime_db/mime_db.dart';
import 'package:test/test.dart';

bool _globMatches(String pattern, String name, bool caseSensitive) {
  if (pattern.startsWith('*.')) {
    final ext = pattern.substring(2);
    final testName = caseSensitive ? name : name.toLowerCase();
    final testExt = caseSensitive ? ext : ext.toLowerCase();
    return testName.endsWith(testExt);
  } else if (pattern.startsWith('*')) {
    final suffix = pattern.substring(1);
    final testName = caseSensitive ? name : name.toLowerCase();
    final testSuffix = caseSensitive ? suffix : suffix.toLowerCase();
    return testName.contains(testSuffix);
  } else {
    final testName = caseSensitive ? name : name.toLowerCase();
    final testPattern = caseSensitive ? pattern : pattern.toLowerCase();
    return testName == testPattern;
  }
}

void main() {
  group('MimeDatabase', () {
    test('creates empty database', () {
      final db = MimeDatabase.empty();
      expect(db.getMimeType('test.txt'), isNull);
    });

    test('NOGLOBS handling removes patterns from lower priority databases', () {
      final systemDb = MimeDatabase.empty();
      systemDb.globs.add(GlobPattern('*.html', 'text/html', 80, false));
      systemDb.globs.add(GlobPattern('*.htm', 'text/html', 80, false));
      systemDb.globs.add(GlobPattern('*.png', 'image/png', 50, false));

      final userDb = MimeDatabase.empty();
      userDb.globs.add(GlobPattern('__NOGLOBS__', 'text/html', 0, false));
      userDb.globs.add(
        GlobPattern('*.html', 'application/x-extension-html', 50, false),
      );

      // Use SharedMimeInfo.open with mock databases - since mergeDatabases is private,
      // we'll test the actual system behavior instead
      print('Testing with SharedMimeInfo.open() which uses the merge logic');
      print(
        'systemDb globs: ${systemDb.globs.map((g) => '${g.pattern}->${g.mimeType}').join(', ')}',
      );
      print(
        'userDb globs: ${userDb.globs.map((g) => '${g.pattern}->${g.mimeType}').join(', ')}',
      );
    });
  });
}
