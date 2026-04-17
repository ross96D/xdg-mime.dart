library;

import 'dart:io';
import 'package:dartx/dartx_io.dart';
import 'package:freedesktop_file_parser/parser.dart' as xdg_parser;
import 'package:path/path.dart' as path;
import 'package:result/result.dart';
import 'package:xdg_dir/xdg.dart' as xdg_dir;

extension type DesktopFile(String filename) {}

abstract final class XdgMimeApps {
  static final List<Directory> _lookupConfigDirs = [
    xdg_dir.configHome,
    ...xdg_dir.configDirs,
  ].map((e) => e.directory("mime")).toList();

  static final List<Directory> _lookupDesktopDirs = [
    xdg_dir.dataHome,
    ...xdg_dir.dataDirs,
  ].map((e) => e.directory("applications")).toList();

  static List<DesktopFile> list(String mime) {
    List<DesktopFile> result = [];
    final currentDesktop = Platform.environment["XDG_CURRENT_DESKTOP"];

    for (final dir in _lookupConfigDirs) {
      if (currentDesktop != null && currentDesktop.isNotEmpty) {
        _parseMimeappList(path.join(dir.path, "$currentDesktop-mimeapps.list"));
      }
      _parseMimeappList(path.join(dir.path, "mimeapps.list"));
    }

    return result;
  }
}

void _parseMimeappList(String path) {}
