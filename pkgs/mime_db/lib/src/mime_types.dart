import 'dart:typed_data';

import 'package:glob/glob.dart';

class MimeData {
  final String mime;
  final int weight;
  final bool caseSensitive;

  const MimeData(this.mime, this.weight, this.caseSensitive);

  @override
  bool operator ==(Object other) {
    return other is MimeData && mime == other.mime && weight == other.weight && caseSensitive == other.caseSensitive;
  }

  @override
  int get hashCode => Object.hashAll([mime, weight, caseSensitive]);
}

class GlobPattern {
  final Glob pattern;
  final MimeData data;

  GlobPattern(this.pattern, this.data);
}

class MagicRule {
  final int priority;
  final String mimeType;
  final List<MagicMatchlet> matchlets;

  MagicRule(this.priority, this.mimeType, this.matchlets);
}

class MagicMatchlet {
  final int rangeStart;
  final int rangeLength;
  late final Uint8List value;
  late final Uint8List? mask;
  final List<MagicMatchlet> children;

  MagicMatchlet({
    required this.rangeStart,
    required this.rangeLength,
    required Uint8List value,
    required int wordSize,
    Uint8List? mask,
    this.children = const [],
    Endian? host,
  }) {
    host ??= Endian.host;

    if (wordSize > 1 && host == Endian.little) {
      for (int i = 0; i < value.length; i += wordSize) {
        final end = i + wordSize < value.length ? i + wordSize : value.length;
        // reverse for little endian compatibility
        final word = Uint8List.sublistView(value, i, end);
        for (int j = 0; j < word.length ~/ 2; j++) {
          final temp = word[j];
          word[j] = word[word.length - j - 1];
          word[word.length - j - 1] = temp;
        }
      }

      if (mask != null && mask.length == value.length) {
        for (int i = 0; i < mask.length; i += wordSize) {
          final end = i + wordSize < mask.length ? i + wordSize : value.length;
          // reverse for little endian compatibility
          final word = Uint8List.sublistView(mask, i, end);
          for (int j = 0; j < word.length ~/ 2; j++) {
            final temp = word[j];
            word[j] = word[word.length - j - 1];
            word[word.length - j - 1] = temp;
          }
        }
      }
    }
    // ignore: prefer_initializing_formals
    this.value = value;
    // ignore: prefer_initializing_formals
    this.mask = mask;
  }
}

class MimeEntry {
  final String mime;
  final String? icon;
  final String? genericIcon;
  final List<String> subclasses;

  const MimeEntry({required this.mime, this.icon, this.genericIcon, this.subclasses = const []});
}
