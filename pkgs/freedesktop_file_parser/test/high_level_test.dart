import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:freedesktop_file_parser/high_level.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

Uint8List bytesFromTestFile(String filepath) {
  return File(path.join(Directory.current.path, "test", filepath)).readAsBytesSync();
}

void main() {
  test("key no value", () {
    final entry = Entry.parse(utf8.encode("[Unit]\nName=")).unwrap();
    final section = entry.section("Unit");
    expect(section, isNotNull);
    expect(section!.attr("Name"), equals([""]));
    expect(section!.hasAttr("Name"), isTrue);
  });

  test("parse icon index", () {
    final entry = Entry.parse(bytesFromTestFile("test_data/gnome-index.theme")).unwrap();
    expect(entry.data.length, equals(68));
    final status48 = entry.section("48x48/status")!;
    expect(status48.attr("Size"), equals(["48"]));
  });

  test("parse firefox desktop", () {
    final entry = Entry.parse(bytesFromTestFile("test_data/firefox.desktop")).unwrap();
    expect(entry.data.length, equals(3));
    final desktopEntry = entry.section("Desktop Entry")!;
    expect(desktopEntry.attr("Name"), equals(["Firefox"]));
    expect(desktopEntry.attrWithParam("GenericName", "ast"), equals(["Restolador Web"]));
    expect(desktopEntry.attrWithParam("GenericName", "ar"), equals(["متصفح ويب"]));
    expect(desktopEntry.attr("Exec"), equals(["/usr/lib/firefox/firefox %u"]));
  });

  test("parse sshd systemd unit", () {
    final entry = Entry.parse(bytesFromTestFile("test_data/sshd.service")).unwrap();
    expect(entry.data.length, equals(3));
    final section = entry.section("Service")!;
    expect(section.attr("ExecReload"), equals(["/bin/kill -HUP \$MAINPID"]));
  });

  test("parse systemd test", () {
    final entry = Entry.parse(bytesFromTestFile("test_data/edge_cases.txt")).unwrap();
    expect(entry.data.length, equals(3));
    final sectionA = entry.section("Section A")!;
    expect(sectionA.attr("KeyOne"), equals(["value 1"]));
    expect(sectionA.attr("KeyTwo"), equals(["value 2"]));

    final sectionB = entry.section("Section B")!;
    expect(sectionB.attr("Setting"), equals(['"something" "some thing" "…"']));
    expect(sectionB.attr("KeyTwo"), equals(["value 2 value 2 continued"]));

    final sectionC = entry.section("Section C")!;
    expect(sectionC.attr("KeyThree"), equals(["value 3 value 3 continued"]));
  });
}
