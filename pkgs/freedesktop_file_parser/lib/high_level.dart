import 'dart:typed_data';

import 'package:freedesktop_file_parser/low_level.dart';
import 'package:freedesktop_file_parser/src/util.dart';

extension type Entry(Map<String, Section> data) {
  static Result<Entry, ParseError> parse(Uint8List input) {
    final sectionsMap = <String, Section>{};

    for (final sectionResult in parseEntryStr(input)) {
      switch (sectionResult) {
        case ResultErr<SectionStr, ParseError>(:final error):
          return Result.error(error);
        case ResultOk<SectionStr, ParseError>(ok: final section):
          final attrMap = sectionsMap.putIfAbsent(section.title, () => Section(<AttrKey, List<String>>{}));
          for (final attr in section.attrs) {
            final key = switch (attr.param != null) {
              true => AttrKey(attr.param!.attrName, attr.param!.param),
              false => AttrKey(attr.name, null),
            };
            final values = attrMap.data.putIfAbsent(key, () => []);
            values.add(attr.value);
          }
      }
    }

    return Result.ok(Entry(sectionsMap));
  }

  Section? section(String title) => data[title];

  bool hasSection(String title) => data.containsKey(title);

  Iterable<MapEntry<String, Section>> sections() => data.entries;

  List<String>? get(String sectionName, String attr) {
    final s = section(sectionName);
    if (s == null) return null;
    return s.attr(attr);
  }

  List<String>? getWithParam(String sectionName, String attr, String param) {
    final s = section(sectionName);
    if (s == null) return null;
    return s.attrWithParam(attr, param);
  }
}

extension type Section(Map<AttrKey, List<String>> data) {
  List<String> attr(String key) => data[AttrKey(key, null)] ?? [];

  List<String> attrWithParam(String key, String param) => data[AttrKey(key, param)] ?? [];

  bool hasAttr(String key) => data.containsKey(AttrKey(key, null));

  bool hasAttrWithParam(String key, String param) => data.containsKey(AttrKey(key, param));

  Iterable<MapEntry<AttrKey, List<String>>> attrs() => data.entries;
}

final class AttrKey {
  final String key;
  final String? param;

  const AttrKey(this.key, this.param);

  @override
  bool operator ==(Object other) {
    return other is AttrKey && key == other.key && param == other.param;
  }

  @override
  int get hashCode => Object.hashAll([key, param]);
}
