library;

import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:xdg_dir/xdg.dart' as xdg_dir;

extension type DesktopFile(String filename) {}

abstract final class XdgMimeApps {
  static final List<Directory> _lookupDirs = [
    xdg_dir.configHome,
    ...xdg_dir.configDirs,
    xdg_dir.dataHome,
    ...xdg_dir.dataDirs,
  ];

  static List<DesktopFile> list(String mime) {
    List<DesktopFile> result = [];
    final currentDesktop = Platform.environment["XDG_CURRENT_DESKTOP"];

    for (final dir in _lookupDirs) {
      if (currentDesktop != null && currentDesktop.isNotEmpty) {
        _parseMimeappList(path.join(dir.path, "$currentDesktop-mimeapps.list"));
      }
      _parseMimeappList(path.join(dir.path, "mimeapps.list"));
    }

    return result;
  }
}

void _parseMimeappList(String path) {

}
