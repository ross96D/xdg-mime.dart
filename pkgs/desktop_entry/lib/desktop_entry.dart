library;

import 'dart:io';

import 'package:dartx/dartx_io.dart';
import 'package:freedesktop_file_parser/parser.dart';
import 'package:result/result.dart';
import 'package:xdg_dir/xdg.dart';
import 'package:path/path.dart' as p;
import 'src/types.dart';

export 'src/types.dart';

class DesktopEntryManager {
  List<({DesktopEntry entry, String path})> _desktopEntries;

  static final List<Directory> _lookupDirs = [
    dataHome,
    ...dataDirs,
  ].map((e) => e.directory("applications")).toList();

  DesktopEntryManager._(this._desktopEntries);

  static Future<DesktopEntryManager> create() async {
    final desktopEntries = <({DesktopEntry entry, String path})>[];

    for (final dir in _lookupDirs) {
      final dirEntries = dir.listSync();
      for (final entry in dirEntries) {
        if (entry is File && p.extension(entry.path) == ".desktop") {
          switch (await DesktopEntry.fromFile(entry)) {
            case ResultOk<DesktopEntry, ParseError>(ok: final desktopEntry):
              desktopEntries.add((path: entry.absolute.path, entry: desktopEntry));
            case ResultErr<DesktopEntry, ParseError>():
              continue;
          }
        }
      }
    }

    return DesktopEntryManager._(desktopEntries);
  }
}
