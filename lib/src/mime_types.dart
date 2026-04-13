import 'dart:typed_data';

class GlobPattern {
  final String pattern;
  final String mimeType;
  final int weight;
  final bool caseSensitive;

  GlobPattern(this.pattern, this.mimeType, this.weight, this.caseSensitive);
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
      this.value = value;

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
        this.mask = mask;
      }
    } else {
      this.value = value;
      this.mask = mask;
    }
  }
}

class MimeTypeEntry {
  final String type;
  final String? comment;
  final String? icon;
  final String? genericIcon;
  final List<String> aliases;
  final List<String> subclasses;

  MimeTypeEntry({
    required this.type,
    this.comment,
    this.icon,
    this.genericIcon,
    this.aliases = const [],
    this.subclasses = const [],
  });
}
