import 'dart:convert';

import 'package:xdg_mime_db/xdg_mime_db.dart';

void main() async {
  final db = await SharedMimeInfo.open();

  // print('Globs count: ${db.globs.length}');

  print('\nTest files:');
  print('  test.html -> ${db.getMimeType('test.html')}');
  print('  image.png -> ${db.getMimeType('image.png')}');
  print('  document.pdf -> ${db.getMimeType('document.pdf')}');
  print('  data.tar.gz -> ${db.getMimeType('data.tar.gz')}');
  print('  video.mkv -> ${db.getMimeType('video.mkv')}');

  print('\nMagic matching with file content:');
  final htmlContent = '<html><body></body></html>';
  print('  HTML string -> ${db.getMimeType('test.txt', data: utf8.encode(htmlContent))}');

  print('\nAlias resolution:');
  print('  audio/x-midi -> ${db.resolveAlias('audio/x-midi')}');

  print('\nSubclasses:');
  print('  text/plain -> ${db.getSubclasses('text/plain')}');

  print('\nIcons:');
  print('  inode/vnd.kde.kio.smb.printer icon -> ${db.getIcon('inode/vnd.kde.kio.smb.printer')}');
  print('  inode/fifo icon -> ${db.getGenericIcon('inode/fifo')}');
  print('  application/x-magicpoint generic-icon -> ${db.getGenericIcon('application/x-magicpoint')}');
}
