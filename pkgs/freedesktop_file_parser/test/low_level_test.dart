import 'dart:convert';
import 'package:freedesktop_file_parser/low_level.dart';
import 'package:freedesktop_file_parser/src/util.dart';
import 'package:test/test.dart';

void main() {
  group('trimWhitespaceFront', () {
    test('trims whitespace from front', () {
      expect(utf8.decode(trimWhitespaceFront(utf8.encode(' \ttest'))), 'test');
    });

    test('returns empty for only whitespace', () {
      expect(utf8.decode(trimWhitespaceFront(utf8.encode('  \t '))), '');
    });

    test('returns same if no leading whitespace', () {
      expect(utf8.decode(trimWhitespaceFront(utf8.encode('test'))), 'test');
    });
  });

  group('trimWhitespaceBack', () {
    test('trims whitespace from back', () {
      expect(utf8.decode(trimWhitespaceBack(utf8.encode('test  \t'))), 'test');
    });

    test('returns empty for only whitespace', () {
      expect(utf8.decode(trimWhitespaceBack(utf8.encode('  \t '))), '');
    });

    test('returns same if no trailing whitespace', () {
      expect(utf8.decode(trimWhitespaceBack(utf8.encode('test'))), 'test');
    });
  });

  group('parseHeader', () {
    test('parses valid header', () {
      final result = parseHeader(utf8.encode('[hello]'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1), 'hello');
      expect(result.$2, isEmpty);
    });

    test('returns null for missing start bracket', () {
      final result = parseHeader(utf8.encode('hello]'));
      expect(result, isNull);
    });

    test('returns null for missing end bracket', () {
      final result = parseHeader(utf8.encode('[hello'));
      expect(result, isNull);
    });

    test('returns null for double start bracket', () {
      final result = parseHeader(utf8.encode('[h[ello]'));
      expect(result, isNull);
    });
  });

  group('nextLine', () {
    test('empty input', () {
      final result = nextLine(utf8.encode(''));
      expect(result.$1, isEmpty);
    });

    test('only whitespace', () {
      final result = nextLine(utf8.encode(' \t \t\n\r\nhello'));
      expect(utf8.decode(result.$1), 'hello');
    });

    test('comment is skipped', () {
      final result = nextLine(utf8.encode('   \t\n# Comment\nhello'));
      expect(utf8.decode(result.$1), 'hello');
    });

    test('no change if already at content', () {
      final result = nextLine(utf8.encode('hello\n'));
      expect(utf8.decode(result.$1), 'hello\n');
    });
  });

  group('parseAttr', () {
    test('parses simple attr', () {
      final result = parseAttr(utf8.encode('hello=world'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), 'hello');
      expect(utf8.decode(result.$1.value), 'world');
      expect(result.$1.param, isNull);
    });

    test('parses attr with param', () {
      final result = parseAttr(utf8.encode('hello[en]=world'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), 'hello[en]');
      expect(utf8.decode(result.$1.value), 'world');
      expect(result.$1.param, isNotNull);
      expect(utf8.decode(result.$1.param!.attrName), 'hello');
      expect(utf8.decode(result.$1.param!.param), 'en');
    });

    test('parses attr with space in value', () {
      final result = parseAttr(utf8.encode('hello=world today'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), 'hello');
      expect(utf8.decode(result.$1.value), 'world today');
    });

    test('parses attr with no value', () {
      final result = parseAttr(utf8.encode('hello='));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), 'hello');
      expect(utf8.decode(result.$1.value), '');
    });

    test('parses attr with no name', () {
      final result = parseAttr(utf8.encode('=world'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), '');
      expect(utf8.decode(result.$1.value), 'world');
    });

    test('returns null for no equals', () {
      final result = parseAttr(utf8.encode('hello'));
      expect(result, isNull);
    });

    test('parses attr with whitespace', () {
      final result = parseAttr(utf8.encode('hello = world today'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.name), 'hello');
      expect(utf8.decode(result.$1.value), 'world today');
    });
  });

  group('parseSection', () {
    test('parses section with attrs', () {
      final result = parseSection(utf8.encode('[apps]\nSize=48\nScale=1'));
      expect(result, isNotNull);
      expect(utf8.decode(result!.$1.title), 'apps');
      expect(result.$1.attrs.length, 2);
      expect(utf8.decode(result.$1.attrs[0].name), 'Size');
      expect(utf8.decode(result.$1.attrs[0].value), '48');
      expect(utf8.decode(result.$1.attrs[1].name), 'Scale');
      expect(utf8.decode(result.$1.attrs[1].value), '1');
    });

    test('returns null for no attrs', () {
      final result = parseSection(utf8.encode('[apps]\n'));
      expect(result, isNull);
    });

    test('returns null for no header', () {
      final result = parseSection(utf8.encode('Size=48\nScale=1'));
      expect(result, isNull);
    });
  });

  group('parseValue', () {
    test('single line', () {
      final result = parseValue(utf8.encode('value\n'));
      expect(result.$1, isEmpty);
      expect(utf8.decode(result.$2), 'value');
    });

    test('two lines with continuation', () {
      final result = parseValue(utf8.encode('value\\\nvalue2\n'));
      expect(result.$1, isEmpty);
      expect(utf8.decode(result.$2), 'value value2');
    });

    test('three lines with continuation', () {
      final result = parseValue(utf8.encode('value\\\nvalue2\\\nvalue3\n'));
      expect(result.$1, isEmpty);
      expect(utf8.decode(result.$2), 'value value2 value3');
    });

    test('three lines with comment in between', () {
      final result = parseValue(utf8.encode('value\\\nvalue2\\\n# comment\nvalue3\n'));
      expect(result.$1, isEmpty);
      expect(utf8.decode(result.$2), 'value value2 value3');
    });
  });

  group('parseEntry', () {
    test('parses desktop entry', () {
      final input = utf8.encode('''
[Desktop Entry]
Name=Firefox
GenericName=Web Browser
GenericName[no]=Nettleser
Exec=firefox %u
Icon=firefox
''');
      final sections = parseEntry(input).toList();
      expect(sections.length, 1);
      expect(sections[0] is ResultOk<SectionBytes, ParseError>, true);
      final section = (sections[0] as ResultOk<SectionBytes, ParseError>).ok;
      expect(utf8.decode(section.title), 'Desktop Entry');
      expect(section.attrs.length, 5);
      expect(utf8.decode(section.attrs[0].name), 'Name');
      expect(utf8.decode(section.attrs[0].value), 'Firefox');
      expect(utf8.decode(section.attrs[2].name), 'GenericName[no]');
      expect(utf8.decode(section.attrs[2].value), 'Nettleser');
      expect(section.attrs[2].param, isNotNull);
      expect(utf8.decode(section.attrs[2].param!.param), 'no');
      expect(utf8.decode(section.attrs[2].param!.attrName), 'GenericName');
    });

    test('parses systemd unit file', () {
      final input = utf8.encode('''
[Unit]
Description=OpenSSH Daemon
Wants=sshdgenkeys.service
After=sshdgenkeys.service
After=network.target

[Service]
ExecStart=/usr/bin/sshd -D
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=always

[Install]
WantedBy=multi-user.target
''');
      final sections = parseEntry(input).whereType<ResultOk<SectionBytes, ParseError>>().map((r) => r.ok).toList();
      expect(sections.length, 3);

      final serviceSection = sections.firstWhere((s) => utf8.decode(s.title) == 'Service');
      final execStart = serviceSection.attrs.firstWhere((a) => utf8.decode(a.name) == 'ExecStart');
      expect(utf8.decode(execStart.value), '/usr/bin/sshd -D');
    });
  });

  group('parseEntryStr', () {
    test('parses desktop entry as strings', () {
      final input = utf8.encode('''
[Desktop Entry]
Name=Firefox
GenericName=Web Browser
''');
      final sections = parseEntryStr(input).toList();
      expect(sections.length, 1);
      expect(sections[0] is ResultOk<SectionStr, ParseError>, true);
      final section = (sections[0] as ResultOk<SectionStr, ParseError>).ok;
      expect(section.title, 'Desktop Entry');
      expect(section.attrs.length, 2);
      expect(section.attrs[0].name, 'Name');
      expect(section.attrs[0].value, 'Firefox');
    });
  });
}
