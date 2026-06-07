// ignore_for_file: depend_on_referenced_packages

import 'package:xdg_mime_db/xdg_mime_db.dart';
import 'package:xdg_mime_apps/xdg_mime_apps.dart';
import 'package:desktop_entry/desktop_entry.dart';

void main() async {
  final mimedb = await SharedMimeInfo.open();
  final dem = await DesktopEntryManager.create();

  final filenames = ["index.html", "index.xhtml", "book.pdf", "image.png", "video.mkv"];

  for (final filename in filenames) {
    final mime = mimedb.getMimeType(filename);
    if (mime == null) {
      print("No mime found for $filename");
      print("");
      continue;
    }
    print("Mime found for $filename is $mime");
    print("Application list for $mime: ${XdgMimeApps.list(mime, desktopEntries: dem).map((e) {
      final entry = dem.get_(e);
      return "$e ${entry?.fields.name} ${entry?.fields.exec}";
    })}");
    String mimeDefaults = mime;
    List<String> defaults = XdgMimeApps.defaults(mimeDefaults, desktopEntries: dem);
    if (defaults.isEmpty) {
      for (final ancester in mimedb.getAncesters(mime)) {
        defaults = XdgMimeApps.defaults(ancester);
        if (defaults.isNotEmpty) {
          break;
        }
      }
    }
    print("Default application for $mime: ${defaults.map((e) {
      final entry = dem.get_(e);
      return "$e ${entry?.fields.name}";
    })}");
    print("");
  }
}
