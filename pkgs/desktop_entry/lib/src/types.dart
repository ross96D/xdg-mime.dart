import 'dart:io';
import 'dart:typed_data';

import 'package:freedesktop_file_parser/parser.dart';
import 'package:result/result.dart';
import 'package:crypto/crypto.dart' show md5;

class DesktopEntry {
  /// For caching the parsing
  final DesktopEntryCache cache;

  /// Desktop entry fields
  final Fields fields;

  /// Desktop entry actions
  final List<({String name, Fields fields})> actions;

  DesktopEntry._(this.cache, this.fields, this.actions);

  static Future<Result<DesktopEntry, ParseError>> fromFile(File desktop) async {
    final mtime = desktop.statSync().modified;
    final path = desktop.absolute.path;
    final bytes = await desktop.readAsBytes();

    switch (Entry.parse(bytes)) {
      case ResultOk<Entry, ParseError>(ok: final entry):
        final mainSection = entry.section("Desktop Entry");
        if (mainSection == null) {
          return Result.error(.unexpected("Not a desktop file. Missing [Desktop Entry] section"));
        }
        final error = Fields.verify(mainSection);
        if (error != null) {
          return Result.error(error);
        }

        final mainFields = Fields._(mainSection);
        final actions = mainFields.actions;
        final actionsSections = <({String name, Fields fields})>[];
        for (final action in actions) {
          final actionSection = entry.section("Desktop Action $action");
          if (actionSection == null) {
            continue;
          }
          actionsSections.add((fields: Fields._(actionSection), name: action));
        }
        return Result.ok(DesktopEntry._(.new(path, mtime, bytes), mainFields, actionsSections));
      case ResultErr<Entry, ParseError>(:final error):
        return Result.error(error);
    }
  }
}

enum DesktopEntryType {
  application,
  link,
  directory;

  static DesktopEntryType? from(String type) {
    return switch (type.toLowerCase()) {
      "application" => .application,
      "link" => .link,
      "directory" => .directory,
      _ => null,
    };
  }
}

class Fields {
  final Section _section;

  static ParseError? verify(Section section) {
    if (section.attr("Name").firstOrNull == null) {
      return ParseError.missingRequiredField("Name");
    }
    final type = section.attr("Type").firstOrNull;
    if (type == null) {
      return ParseError.missingRequiredField("Type");
    } else if (DesktopEntryType.from(type) == null) {
      return ParseError.invalidFieldValue("Type", type);
    }
    return null;
  }

  Fields._(this._section) : assert(verify(_section) == null, "${verify(_section)?.toString()}");

  /// This specification defines 3 types of desktop entries: `Application` (type 1),
  /// `Link` (type 2) and `Directory` (type 3). To allow the addition of new types
  /// in the future, implementations should ignore desktop entries with an unknown type.
  DesktopEntryType get type => DesktopEntryType.from(_section.attr("Type").first)!;

  /// Specific name of the application, for example "Mozilla".
  String get name => _section.attr("Name").first;

  /// Specific name of the application, for example "Mozilla".
  String? nameLang(String lang) => _section.attrWithParam("Name", lang).firstOrNull;

  /// Generic name of the application, for example "Web Browser".
  String? get genericName => _section.attr("GenericName").firstOrNull;

  /// Generic name of the application, for example "Web Browser".
  String? genericNameLang(String lang) => _section.attrWithParam("GenericName", lang).firstOrNull;

  /// `NoDisplay` means "this application exists, but don't display it in the menus".
  /// This can be useful to e.g. associate this application with MIME types, so that
  /// it gets launched from a file manager (or other apps), without having a menu entry.
  bool get noDisplay => _section.attr("NoDisplay").firstOrNull == "true";

  /// Comment describing what this application does.
  String? get comment => _section.attr("Comment").firstOrNull;

  /// Comment describing what this application does.
  String? commentLang(String lang) => _section.attrWithParam("Comment", lang).firstOrNull;

  /// Icon to display in file manager, menu, etc.
  String? get icon => _section.attr("Icon").firstOrNull;

  /// `Hidden` should have been called `Deleted`. It means the user deleted (at their level)
  /// something that was present. It should only be recognized when `TryExec` and `Exec`
  /// are absent.
  bool get hidden => _section.attr("Hidden").firstOrNull == "true";

  /// A list of strings identifying the desktop environments that should display
  /// this desktop entry.
  List<String> get onlyShowIn => _section.attr("OnlyShowIn").firstOrNull?.entryList() ?? [];

  /// A list of strings identifying the desktop environments that should not display
  /// this desktop entry.
  List<String> get notShowIn => _section.attr("NotShowIn").firstOrNull?.entryList() ?? [];

  /// A boolean value specifying if D-Bus activation is supported for this application.
  /// If this key is missing, the default value is `false`.
  bool get dbusActivatable => _section.attr("DBusActivatable").firstOrNull == "true";

  /// Path to an executable file on disk used to determine if the program is actually
  /// installed. If the path is not an absolute path, the file is looked up in the
  /// `$PATH` environment variable. If the file is not present or if it is not executable,
  /// the entry may be ignored (not be used in menus, for example).
  String? get tryExec => _section.attr("TryExec").firstOrNull;

  /// Program to execute, possibly with arguments. See the `Exec` key documentation
  /// for details on how this key works. The `Exec` key is required if `DBusActivatable`
  /// is not set to `true`. Even if `DBusActivatable` is `true`, `Exec` should be
  /// specified for compatibility with implementations that do not understand
  /// `DBusActivatable`.
  String? get exec => _section.attr("Exec").firstOrNull;

  /// If entry is of type `Application`, the working directory to run the program in.
  String? get path => _section.attr("Path").firstOrNull;

  /// Whether the program runs in a terminal window.
  bool get terminal => _section.attr("Terminal").firstOrNull == "true";

  /// Identifiers for application actions. This can be used to tell the application to
  /// make a specific action, different from the default behavior.
  List<String> get actions => _section.attr("Actions").firstOrNull?.entryList() ?? [];

  /// The MIME type(s) supported by this application.
  List<String> get mimeType => _section.attr("MimeType").firstOrNull?.entryList() ?? [];

  /// Categories in which the entry should be shown in a menu
  /// (for possible values see the Desktop Menu Specification).
  List<String> get categories => _section.attr("Categories").firstOrNull?.entryList() ?? [];

  /// A list of interfaces that this application implements.
  List<String> get implements => _section.attr("Implements").firstOrNull?.entryList() ?? [];

  /// A list of strings which may be used in addition to other metadata to describe
  /// this entry. The values are not meant for display, and should not be redundant
  /// with the values of `Name` or `GenericName`.
  List<String> get keywords => _section.attr("Keywords").firstOrNull?.entryList() ?? [];

  /// A list of strings which may be used in addition to other metadata to describe
  /// this entry. The values are not meant for display, and should not be redundant
  /// with the values of `Name` or `GenericName`.
  List<String> keywordsLang(String lang) {
    return _section.attrWithParam("Keywords", lang).firstOrNull?.entryList() ?? [];
  }

  /// If true, it is KNOWN that the application will send a "remove" message when
  /// started with the `DESKTOP_STARTUP_ID` environment variable set. If false, it is
  /// KNOWN that the application does not work with startup notification at all.
  /// If absent, a reasonable handling is up to implementations.
  bool get startupNotify => _section.attr("StartupNotify").firstOrNull == "true";

  /// If specified, it is known that the application will map at least one window
  /// with the given string as its WM class or WM name hint.
  String? get startupWmClass => _section.attr("StartupWMClass").firstOrNull;

  /// If entry is Link type, the URL to access.
  String? get url => _section.attr("URL").firstOrNull;

  /// If true, the application prefers to be run on a more powerful discrete GPU
  /// if available. This key is only a hint and support might not be present
  /// depending on the implementation.
  bool get prefersNonDefaultGpu => _section.attr("PrefersNonDefaultGPU").firstOrNull == "true";
}

extension<E> on List<E> {
  E? get firstOrNull {
    if (length == 0) {
      return null;
    } else {
      return this[0];
    }
  }
}

extension on String {
  List<String> entryList() {
    final result = split(";");
    for (int i = 0; i < result.length; i++) {
      result[i] = result[i].trim();
    }
    return result;
  }
}

class DesktopEntryCache {
  final String path;
  final DateTime mtime;
  final Uint8List hashedContent;

  DesktopEntryCache(this.path, this.mtime, Uint8List content) : hashedContent = _hash(content);

  static Uint8List _hash(Uint8List input) {
    final digest = md5.convert(input);
    return Uint8List.fromList(digest.bytes);
  }

  @override
  // ignore: hash_and_equals
  bool operator ==(covariant DesktopEntryCache other) {
    if (path != other.path) {
      return false;
    }
    final mtimeDiff = mtime.difference(other.mtime).abs();
    if (mtimeDiff < Duration(milliseconds: 10)) {
      return true;
    }
    for (int i = 0; i < hashedContent.length; i++) {
      if (hashedContent[i] != other.hashedContent[i]) {
        return false;
      }
    }
    return true;
  }
}
