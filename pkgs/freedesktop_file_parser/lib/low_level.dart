import 'dart:convert';
import 'dart:typed_data';

import 'package:freedesktop_file_parser/src/util.dart';

enum ParseErrorKind { utf8Error, unexpectedToken, incompleteInput }

const _bracketOpen = 91; // [
const _bracketClose = 93; // ]
const _backSlash = 92; // \
const _newLine = 10; // \n
const _tab = 9; // \t
const _return = 13; // \r
const _equals = 61; // =
const _hash = 35; // #
const _dottedComma = 59; // ;
const _whitespace = 32; //

class ParseError {
  final ParseErrorKind kind;
  final Uint8List bytes;
  final String message;

  const ParseError._(this.kind, this.bytes, this.message);

  factory ParseError.utf8(Uint8List bytes, String message) {
    return ParseError._(ParseErrorKind.utf8Error, bytes, message);
  }

  factory ParseError.unexpected(String message, [Uint8List? bytes]) {
    return ParseError._(ParseErrorKind.unexpectedToken, bytes ?? Uint8List(0), message);
  }

  factory ParseError.incomplete(String message, [Uint8List? bytes]) {
    return ParseError._(ParseErrorKind.incompleteInput, bytes ?? Uint8List(0), message);
  }

  @override
  String toString() => 'ParseError($kind: $message)';
}

class AttrBytes {
  final Uint8List name;
  final Uint8List value;
  final ParamBytes? param;

  const AttrBytes(this.name, this.value, this.param);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttrBytes &&
          runtimeType == other.runtimeType &&
          _bytesEqual(name, other.name) &&
          _bytesEqual(value, other.value) &&
          param == other.param;

  @override
  int get hashCode => Object.hash(name, value, param);

  @override
  String toString() {
    final nameStr = _tryUtf8(name);
    final valueStr = _tryUtf8(value);
    return 'AttrBytes(name: $nameStr, value: $valueStr, param: $param)';
  }
}

class ParamBytes {
  final Uint8List param;
  final Uint8List attrName;

  const ParamBytes(this.param, this.attrName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParamBytes &&
          runtimeType == other.runtimeType &&
          _bytesEqual(param, other.param) &&
          _bytesEqual(attrName, other.attrName);

  @override
  int get hashCode => Object.hash(param, attrName);

  @override
  String toString() {
    final attrNameStr = _tryUtf8(attrName);
    final paramStr = _tryUtf8(param);
    return 'ParamBytes(attrName: $attrNameStr, param: $paramStr)';
  }
}

class SectionBytes {
  final Uint8List title;
  final List<AttrBytes> attrs;

  const SectionBytes(this.title, this.attrs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionBytes &&
          runtimeType == other.runtimeType &&
          _bytesEqual(title, other.title) &&
          _listEquals(attrs, other.attrs);

  @override
  int get hashCode => Object.hash(title, attrs);

  @override
  String toString() {
    final titleStr = _tryUtf8(title);
    return 'SectionBytes(title: $titleStr, attrs: $attrs)';
  }
}

class AttrStr {
  final String name;
  final String value;
  final ParamStr? param;

  const AttrStr(this.name, this.value, this.param);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttrStr &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          value == other.value &&
          param == other.param;

  @override
  int get hashCode => Object.hash(name, value, param);

  @override
  String toString() => 'AttrStr(name: $name, value: $value, param: $param)';
}

class ParamStr {
  final String param;
  final String attrName;

  const ParamStr(this.param, this.attrName);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParamStr && runtimeType == other.runtimeType && param == other.param && attrName == other.attrName;

  @override
  int get hashCode => Object.hash(param, attrName);

  @override
  String toString() => 'ParamStr(attrName: $attrName, param: $param)';
}

class SectionStr {
  final String title;
  final List<AttrStr> attrs;

  const SectionStr(this.title, this.attrs);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SectionStr &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          _listEquals(attrs, other.attrs);

  @override
  int get hashCode => Object.hash(title, attrs);

  @override
  String toString() => 'SectionStr(title: $title, attrs: $attrs)';
}

bool _bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _tryUtf8(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } catch (_) {
    return '0x${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

String? _tryParseUtf8(Uint8List input) {
  try {
    return utf8.decode(input);
  } catch (_) {
    return null;
  }
}

AttrStr _attrBytesToStr(AttrBytes attr) {
  final nameStr = _tryParseUtf8(attr.name);
  if (nameStr == null) {
    throw ParseError.utf8(attr.name, 'Invalid UTF-8 in attribute name');
  }

  final valueBytes = attr.value;
  final valueStr = _tryParseUtf8(valueBytes);
  if (valueStr == null) {
    throw ParseError.utf8(valueBytes, 'Invalid UTF-8 in attribute value');
  }

  ParamStr? param;
  if (attr.param != null) {
    final attrNameStr = _tryParseUtf8(attr.param!.attrName);
    final paramStr = _tryParseUtf8(attr.param!.param);
    if (attrNameStr == null || paramStr == null) {
      throw ParseError.utf8(attrNameStr == null ? attr.param!.attrName : attr.param!.param, 'Invalid UTF-8 in param');
    }
    param = ParamStr(paramStr, attrNameStr);
  }

  return AttrStr(nameStr, valueStr, param);
}

SectionStr _sectionBytesToStr(SectionBytes section) {
  final titleStr = _tryParseUtf8(section.title);
  if (titleStr == null) {
    throw ParseError.utf8(section.title, 'Invalid UTF-8 in section title');
  }

  final attrs = section.attrs.map(_attrBytesToStr).toList();
  return SectionStr(titleStr, attrs);
}

bool _isNotWhitespace(int c) => c != _newLine && c != _tab && c != _return && c != _whitespace;

int _findBracketClose(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (input[i] == _bracketClose) return i;
  }
  return -1;
}

int _findEquals(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (input[i] == _equals) return i;
  }
  return -1;
}

int _findNewlineOrBackslash(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (input[i] == _newLine || input[i] == _backSlash) return i;
  }
  return -1;
}

int _findNewline(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (input[i] == _newLine) return i;
  }
  return -1;
}

int _findNonWhitespace(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (_isNotWhitespace(input[i])) return i;
  }
  return -1;
}

int _findNonWhitespaceBackwards(Uint8List input, int end) {
  for (var i = end - 1; i >= 0; i--) {
    if (_isNotWhitespace(input[i])) return i;
  }
  return -1;
}

int _findBracketOpen(Uint8List input, int start) {
  for (var i = start; i < input.length; i++) {
    if (input[i] == _bracketOpen) return i;
  }
  return -1;
}

(Uint8List, Uint8List)? parseHeader(Uint8List input) {
  if (input.isEmpty || input[0] != _bracketOpen) return null;
  var i = 1;
  while (i < input.length && input[i] != _bracketClose && input[i] != _bracketOpen) {
    i++;
  }
  if (i >= input.length || input[i] != _bracketClose) return null;
  final title = Uint8List.sublistView(input, 1, i);
  final rem = i < input.length ? Uint8List.sublistView(input, i + 1) : Uint8List(0);
  return (title, rem);
}

bool _isCommentLine(Uint8List input) {
  if (input.isEmpty) return false;
  return input[0] == _hash || input[0] == _dottedComma;
}

(Uint8List, Uint8List) nextLine(Uint8List input) {
  if (input.isEmpty) return (Uint8List(0), Uint8List(0));

  var pos = _findNonWhitespace(input, 0);
  if (pos < 0) return (Uint8List(0), Uint8List(0));

  if (_isCommentLine(Uint8List.sublistView(input, pos))) {
    final nlPos = _findNewline(input, pos);
    if (nlPos < 0) return (Uint8List(0), Uint8List(0));
    return nextLine(Uint8List.sublistView(input, nlPos + 1));
  }

  return (Uint8List.sublistView(input, pos), Uint8List(0));
}

(Uint8List, Uint8List) findStart(Uint8List input) {
  for (var i = 0; i < input.length; i++) {
    if (input[i] == _bracketOpen) {
      return (Uint8List.sublistView(input, i), Uint8List.sublistView(input, 0, i));
    }
  }
  return (Uint8List(0), input);
}

Uint8List trimWhitespaceFront(Uint8List input) {
  final pos = _findNonWhitespace(input, 0);
  if (pos < 0) return Uint8List(0);
  return Uint8List.sublistView(input, pos);
}

Uint8List trimWhitespaceBack(Uint8List input) {
  if (input.isEmpty) return Uint8List(0);
  final pos = _findNonWhitespaceBackwards(input, input.length);
  if (pos < 0) return Uint8List(0);
  return Uint8List.sublistView(input, 0, pos + 1);
}

ParamBytes? _parseParams(Uint8List name) {
  final bracketPos = _findBracketOpen(name, 0);
  if (bracketPos < 0) return null;

  final closePos = _findBracketClose(name, bracketPos + 1);
  if (closePos < 0) return null;

  final attrName = Uint8List.sublistView(name, 0, bracketPos);
  final param = Uint8List.sublistView(name, bracketPos + 1, closePos);
  return ParamBytes(param, attrName);
}

enum LineCont { end, cont }

(Uint8List, LineCont, Uint8List) _valueLine(Uint8List input) {
  final pos = _findNewlineOrBackslash(input, 0);

  if (pos < 0) {
    return (Uint8List(0), LineCont.end, input);
  }

  if (input[pos] == _backSlash) {
    final rest = pos + 1 < input.length ? Uint8List.sublistView(input, pos + 1) : Uint8List(0);
    final nextResult = nextLine(rest);
    return (nextResult.$1, LineCont.cont, Uint8List.sublistView(input, 0, pos));
  }

  return (Uint8List.sublistView(input, pos + 1), LineCont.end, Uint8List.sublistView(input, 0, pos));
}

(Uint8List, Uint8List) parseValue(Uint8List input) {
  final lineContResult = _valueLine(input);
  final cont = lineContResult.$2;
  var line = lineContResult.$3;
  var rem = lineContResult.$1;

  line = trimWhitespaceFront(line);

  if (cont == LineCont.end) {
    return (rem, line);
  }

  final result = BytesBuilder(copy: false);
  result.add(line);
  result.addByte(_whitespace);

  while (true) {
    final nextLineContResult = _valueLine(rem);
    result.add(nextLineContResult.$3);
    rem = nextLineContResult.$1;
    if (nextLineContResult.$2 == LineCont.end) break;
    result.addByte(_whitespace);
  }

  return (rem, result.takeBytes());
}

(AttrBytes, Uint8List)? parseAttr(Uint8List input) {
  if (input.isNotEmpty && input[0] == _bracketOpen) return null;

  final eqPos = _findEquals(input, 0);
  if (eqPos < 0) return null;

  final name = trimWhitespaceBack(Uint8List.sublistView(input, 0, eqPos));
  final valueResult = parseValue(Uint8List.sublistView(input, eqPos + 1));
  final rem = valueResult.$1;
  final value = valueResult.$2;
  final nextResult = nextLine(rem);

  return (AttrBytes(name, value, _parseParams(name)), nextResult.$1);
}

(SectionBytes, Uint8List)? parseSection(Uint8List input) {
  final headerResult = parseHeader(input);
  if (headerResult == null) return null;

  final title = headerResult.$1;
  final afterHeader = headerResult.$2;
  final afterNewlineResult = nextLine(afterHeader);
  final afterNewline = afterNewlineResult.$1;

  if (afterNewline.isEmpty && afterHeader.isEmpty) {
    return null;
  }

  final attrs = <AttrBytes>[];
  var remainder = afterNewline;

  while (true) {
    final attrResult = parseAttr(remainder);
    if (attrResult == null) break;
    attrs.add(attrResult.$1);
    remainder = attrResult.$2;
    if (remainder.isEmpty) break;
  }

  if (attrs.isEmpty) return null;

  return (SectionBytes(title, attrs), remainder);
}

class SectionBytesIter implements Iterator<Result<SectionBytes, ParseError>> {
  Uint8List _rem;
  bool _error = false;
  Result<SectionBytes, ParseError>? _current;
  bool _hasCurrent = false;

  SectionBytesIter(this._rem);

  @override
  Result<SectionBytes, ParseError> get current {
    if (!_hasCurrent) {
      throw StateError('No element');
    }
    return _current!;
  }

  @override
  bool moveNext() {
    if (_rem.isEmpty || _error) return false;

    final startResult = findStart(_rem);
    final newRem = startResult.$1;
    if (newRem.isEmpty) {
      _rem = Uint8List(0);
      return false;
    }

    _rem = newRem;

    final sectionResult = parseSection(_rem);
    if (sectionResult == null) {
      _error = true;
      _current = Result<SectionBytes, ParseError>.error(
        ParseError.unexpected('Failed to parse section', Uint8List.fromList(_rem.take(50).toList())),
      );
      _hasCurrent = true;
      return true;
    }

    final section = sectionResult.$1;
    _rem = sectionResult.$2;
    _current = Result.ok(section);
    _hasCurrent = true;
    return true;
  }
}

class SectionBytesIterable extends Iterable<Result<SectionBytes, ParseError>> {
  final Uint8List _input;

  SectionBytesIterable(this._input);

  @override
  Iterator<Result<SectionBytes, ParseError>> get iterator => SectionBytesIter(_input);
}

SectionBytesIterable parseEntry(Uint8List input) => SectionBytesIterable(input);

class SectionStrIter implements Iterator<Result<SectionStr, ParseError>> {
  final SectionBytesIter _internal;
  Result<SectionStr, ParseError>? _current;
  bool _hasCurrent = false;

  SectionStrIter(Uint8List input) : _internal = SectionBytesIter(input);

  @override
  Result<SectionStr, ParseError> get current {
    if (!_hasCurrent) {
      throw StateError('No element');
    }
    return _current!;
  }

  @override
  bool moveNext() {
    if (!_internal.moveNext()) return false;

    final result = _internal.current;
    switch (result) {
      case ResultOk<SectionBytes, ParseError>(:final ok):
        SectionStr? sectionStr;
        try {
          sectionStr = _sectionBytesToStr(ok);
          _current = Result<SectionStr, ParseError>.ok(sectionStr);
        } catch (e) {
          if (e is ParseError) {
            _current = Result<SectionStr, ParseError>.error(e);
          } else {
            _current = Result<SectionStr, ParseError>.error(ParseError.unexpected(e.toString()));
          }
        }
      case ResultErr<SectionBytes, ParseError>(:final error):
        _current = Result.error(error);
    }

    _hasCurrent = true;
    return true;
  }
}

class SectionStrIterable extends Iterable<Result<SectionStr, ParseError>> {
  final Uint8List _input;

  SectionStrIterable(this._input);

  @override
  Iterator<Result<SectionStr, ParseError>> get iterator => SectionStrIter(_input);
}

SectionStrIterable parseEntryStr(Uint8List input) => SectionStrIterable(input);
