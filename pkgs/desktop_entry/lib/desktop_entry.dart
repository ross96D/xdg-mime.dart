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
  final List<DesktopEntry> _sortedDesktopEntries;

  static final List<Directory> _lookupDirs = [
    dataHome,
    ...dataDirs,
  ].map((e) => e.directory("applications")).toList();

  static int _compare(DesktopEntry a, DesktopEntry b) {
    return a.fields.name.compareTo(b.fields.name);
  }

  DesktopEntryManager._(this._sortedDesktopEntries);

  static Future<DesktopEntryManager> create() async {
    final desktopEntries = <DesktopEntry>[];

    for (final dir in _lookupDirs) {
      final dirEntries = dir.listSync();
      for (final entry in dirEntries) {
        if (entry is File && p.extension(entry.path) == ".desktop") {
          switch (await DesktopEntry.fromFile(entry)) {
            case ResultOk<DesktopEntry, ParseError>(ok: final desktopEntry):
              desktopEntries.add(desktopEntry);
            case ResultErr<DesktopEntry, ParseError>():
              // TODO 2: log error
              continue;
          }
        }
      }
    }

    desktopEntries.sort(_compare);
    // TODO 1: remove repeted entries by name. Select the one
    // with a bigger path priority given the lookup directories

    return DesktopEntryManager._(desktopEntries);
  }

  // ignore: non_constant_identifier_names, unused_element
  DesktopEntry? __get__(String name) {
    final index = _binarySearchBy(_sortedDesktopEntries, (e) => e.fields.name, (a, b) => a.compareTo(b), name);
    if (index == -1) {
      return null;
    }
    return _sortedDesktopEntries[index];
  }
}


/// Copy from collections package to change the value type :)
///
///
/// Returns a position of the [value] in [sortedList], if it is there.
///
/// If the list isn't sorted according to the [compare] function on the [keyOf]
/// property of the elements, the result is unpredictable.
///
/// Returns -1 if [value] is not in the list by default.
///
/// If [start] and [end] are supplied, only that range is searched,
/// and only that range need to be sorted.
int _binarySearchBy<E, K>(List<E> sortedList, K Function(E element) keyOf,
    int Function(K, K) compare, K value,
    [int start = 0, int? end]) {
  end = RangeError.checkValidRange(start, end, sortedList.length);
  var min = start;
  var max = end;
  var key = value;
  while (min < max) {
    var mid = min + ((max - min) >> 1);
    var element = sortedList[mid];
    var comp = compare(keyOf(element), key);
    if (comp == 0) return mid;
    if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return -1;
}
