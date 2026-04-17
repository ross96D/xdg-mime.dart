library;

import 'dart:io';

import 'package:dartx/dartx_io.dart';
import 'package:xdg_dir/xdg.dart';

import 'src/types.dart';
export 'src/types.dart';

class DesktopEntryManager {
  List<({DesktopEntry entry, String path})> desktopEntries;

  static final List<Directory> _lookupDirs = [
    dataHome,
    ...dataDirs,
  ].map((e) => e.directory("applications")).toList();

  DesktopEntryManager.create() : desktopEntries = [] {

  }
}
