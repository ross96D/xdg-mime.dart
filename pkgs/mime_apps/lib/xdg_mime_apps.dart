library;

import 'dart:io';
import 'package:dartx/dartx_io.dart';
import 'package:desktop_entry/desktop_entry.dart';
import 'package:freedesktop_file_parser/parser.dart' as xdg_parser;
import 'package:path/path.dart' as path;
import 'package:result/result.dart';
import 'package:xdg_dir/xdg.dart' as xdg_dir;
import 'package:xdg_mime_apps/src/type.dart';

abstract final class XdgMimeApps {
  static Mimelist? __mimelist;
  static Mimelist get _mimelist {
    if (__mimelist != null) return __mimelist!;
    __mimelist = _parseMimelist();
    return __mimelist!;
  }

  static Mimelist _parseMimelist() {
    final mimelist = Mimelist.empty();
    for (final dir in _lookupConfigDirs) {
      final currentDesktop = Platform.environment["XDG_CURRENT_DESKTOP"];
      for (final mimeFile in [
        if (currentDesktop != null) File(path.join(dir.path, "$currentDesktop-mimeapps.list")),
        File(path.join(dir.path, "mimeapps.list")),
      ]) {
        if (mimeFile.existsSync()) {
          _parseMimeappList(mimeFile, mimelist);
        }
      }
    }
    return mimelist;
  }

  static List<String> list(String mime, {DesktopEntryManager? desktopEntries}) {
    final added = _mimelist.added[mime];
    final removed = _mimelist.removed[mime];

    if (added != null) {
      final result = _subtract(added, removed);
      if (result.isNotEmpty) return result.toList();
    }

    if (desktopEntries != null) {
      final desktopMatches = desktopEntries.findByMimeType(mime);
      if (removed != null) {
        final removedSet = removed;
        desktopMatches.removeWhere((e) => removedSet.contains(e));
      }
      if (desktopMatches.isNotEmpty) return desktopMatches;
    }

    return [];
  }

  static List<String> defaults(String mime, {DesktopEntryManager? desktopEntries}) {
    final def = _mimelist.defaults[mime];
    if (def != null && def.isNotEmpty) {
      return def.toList(growable: false);
    }

    return list(mime, desktopEntries: desktopEntries);
  }

  static final List<Directory> _lookupConfigDirs = [
    xdg_dir.configHome,
    ...xdg_dir.configDirs,
  ].toList();

  static final List<Directory> _lookupDesktopDirs = [
    xdg_dir.dataHome,
    ...xdg_dir.dataDirs,
  ].map((e) => e.directory("applications")).toList();
}

void _parseMimeappList(File mimeFile, Mimelist list) {
  final entry = switch (xdg_parser.Entry.parse(mimeFile.readAsBytesSync())) {
    ResultOk<xdg_parser.Entry, xdg_parser.ParseError>(:final ok) => ok,
    ResultErr<xdg_parser.Entry, xdg_parser.ParseError>() => null,
  };
  if (entry == null) {
    return;
  }

  final addedSection = entry.section("Added Associations");
  final removedSection = entry.section("Removed Associations");
  final defaultSection = entry.section("Default Applications");

  if (addedSection != null) {
    for (final entry in addedSection.attrs()) {
      final mime = entry.key.key;
      Set<String>? value = entry.value.firstOrNull
          ?.split(";")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (value == null || value.isEmpty) {
        continue;
      }

      if (list.removed.containsKey(mime)) {
        final removedSet = list.removed[mime]!;
        value.removeWhere((e) => removedSet.contains(e));
      }
      if (value.isEmpty) {
        continue;
      }

      if (list.added.containsKey(mime)) {
        list.added[mime]!.addAll(value);
      } else {
        list.added[mime] = value;
      }
    }
  }

  if (removedSection != null) {
    for (final entry in removedSection.attrs()) {
      final mime = entry.key.key;
      Set<String>? value = entry.value.firstOrNull
          ?.split(";")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (value == null || value.isEmpty) {
        continue;
      }

      if (list.removed.containsKey(mime)) {
        list.removed[mime]!.addAll(value);
      } else {
        list.removed[mime] = value;
      }
    }
  }

  if (defaultSection != null) {
    for (final entry in defaultSection.attrs()) {
      final mime = entry.key.key;
      Set<String>? value = entry.value.firstOrNull
          ?.split(";")
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
      if (value == null || value.isEmpty) {
        continue;
      }

      if (list.defaults.containsKey(mime)) {
        list.defaults[mime]!.addAll(value);
      } else {
        list.defaults[mime] = value;
      }
    }
  }
}

Set<String> _subtract(Set<String> a, Set<String>? b) {
  if (b == null || b.isEmpty) return a.toList(growable: false).toSet();
  final result = <String>{};
  for (final e in a) {
    if (!b.contains(e)) {
      result.add(e);
    }
  }
  return result;
}
