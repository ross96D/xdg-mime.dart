import 'package:xdg_mime_apps/xdg_mime_apps.dart';

void main() {
  print("list text/plain ${XdgMimeApps.list("text/plain")}");
  print("default for text/plain ${XdgMimeApps.defaults("text/plain")}");
}
