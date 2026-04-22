import 'package:xdg_mime_db/xdg_mime_db.dart';
import 'package:xdg_mime_apps/xdg_mime_apps.dart';

void main() async {
  final mimedb = await SharedMimeInfo.open();

  final filenames = ["index.html", "index.xhtml", "book.pdf", "image.png"];

  for (final filename in filenames) {
    final mime = mimedb.getMimeType(filename);
    if (mime == null) {
      print("No mime found for $filename");
      print("");
      continue;
    }
    print("Mime found for $filename is $mime");
    print("Application list for $mime: ${XdgMimeApps.list(mime)}");
    String mimeDefaults = mime;
    List<String> defaults = XdgMimeApps.defaults(mimeDefaults);
    if (defaults.isEmpty) {
      for (final ancester in mimedb.getAncesters(mime)) {
        defaults = XdgMimeApps.defaults(ancester);
        if (defaults.isNotEmpty) {
          break;
        }
      }
    }
    print("Default application for $mime: $defaults");
    print("");
  }
}
