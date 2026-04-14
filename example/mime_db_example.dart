import 'dart:convert';

import 'package:mime_db/mime_db.dart';

void main() async {
  final db = await MimeDatabase.fromDirectory("/usr/share/mime");

  print('Globs count: ${db.globs.length}');

  print('\nTest files:');
  print('  test.html -> ${db.getMimeTypeFromFilename('test.html')}');
  print('  image.png -> ${db.getMimeTypeFromFilename('image.png')}');
  print('  document.pdf -> ${db.getMimeTypeFromFilename('document.pdf')}');
  print('  data.tar.gz -> ${db.getMimeTypeFromFilename('data.tar.gz')}');

  print('\nMagic matching with file content:');
  final htmlContent = '<html><body></body></html>';
  print('  HTML string -> ${db.getMimeTypeFromFilename('test.txt', data: utf8.encode(htmlContent))}');

  print('\nAlias resolution:');
  print('  audio/x-midi -> ${db.resolveAlias('audio/x-midi')}');

  print('\nSubclasses:');
  print('  text/html -> ${db.getSubclasses('text/html')}');

  print('\nIcons:');
  print('  image/png icon -> ${db.getIcon('image/png')}');
  print('  image/png generic-icon -> ${db.getGenericIcon('image/png')}');
}
