import 'dart:io';
import 'dart:typed_data';

import 'package:glob/glob.dart';
import 'byte_reader.dart';
import 'ext.dart';
import 'mime_types.dart';
import 'reverse_trie.dart';
import 'package:path/path.dart' as path;
import 'package:xdg_dir/xdg.dart' as xdg_dir;

export 'mime_database.dart';

class MimeDatabase {
  final Map<String, String> _aliases = {};
  final Map<String, List<String>> _subclasses = {};
  final Map<String, String> _icons = {};
  final Map<String, String> _genericIcons = {};
  final List<MagicRule> _magicRules = [];
  final List<GlobPattern> _globs = [];
  final Map<String, MimeData> _literals = {};
  final List<ReverseTrie> _reverseSuffixTree = [];
  final Directory? _basePath;

  MimeDatabase._([this._basePath]);

  MimeDatabase.empty() : _basePath = null;

  String? getMimeType(String filename, {Uint8List? data}) {
    // literals evaluation
    {
      MimeData? mimeData = _literals[filename];
      if (mimeData != null) {
        return mimeData.mime;
      }
      mimeData = _literals[filename.toLowerCase()];
      if (mimeData != null && mimeData.caseSensitive == false) {
        return mimeData.mime;
      }
    }

    // suffix tree evaluation
    {
      for (final tree in _reverseSuffixTree) {
        final mimeData = tree.match(filename);
        if (mimeData != null) {
          return mimeData.mime;
        }
      }
    }

    var matches = <MimeData>[];
    // glob matching
    {
      for (final pattern in _globs) {
        if (matches.isEmpty) {
          if (pattern.pattern.matches(filename)) {
            matches.add(pattern.data);
          }
        } else {
          if (pattern.data.weight < matches[0].weight) {
            continue;
          }
          if (pattern.pattern.matches(filename)) {
            if (pattern.data.weight > matches[0].weight) {
              matches = matches.sublist(0, 1);
              matches[0] = pattern.data;
            } else {
              matches.add(pattern.data);
            }
          }
        }
      }
    }

    if (matches.isEmpty) {
      // TODO 2: If no match can be made we need to check the N first bytes and see if they are UTF8
      // visible characters or at least ASCII characters and return a text/plain, otherwise return a application/octet-stream
      return data != null ? _matchMagic(data) : null;
    }

    if (matches.length == 1) {
      return matches[0].mime;
    }

    final firstMatch = matches[0];
    if (matches.every((e) => e.mime == firstMatch.mime)) {
      return firstMatch.mime;
    }

    if (data != null) {
      final magic = _matchMagic(data);
      if (magic != null) {
        for (final match in matches) {
          if (match.mime == magic) {
            return match.mime;
          }
        }
        return magic;
      }
    }

    return firstMatch.mime;
  }

  static Future<MimeDatabase> fromDirectory(Directory dir) async {
    final db = MimeDatabase._(dir);
    await db._load();
    return db;
  }

  Future<void> _load() async {
    if (_basePath == null) return;

    final cacheFile = path.join(_basePath.path, 'mime.cache');
    final file = File(cacheFile);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      _parseCacheFile(bytes);
    }
  }

  void _parseCacheFile(Uint8List data) {
    if (data.length < 44) return;

    final byteReader = ByteReader(ByteData.sublistView(data));
    final majorVersion = byteReader.readUint16();
    final minorVersion = byteReader.readUint16();
    if (majorVersion != 1) return;
    final _ = minorVersion; // minor version should break the parse cache file functionality

    final aliasListOffset = byteReader.readUint32();
    final parentListOffset = byteReader.readUint32();
    final literalListOffset = byteReader.readUint32();
    // ignore: unused_local_variable
    final reverseSuffixTreeOffset = byteReader.readUint32();
    final globListOffset = byteReader.readUint32();
    final magicListOffset = byteReader.readUint32();
    // ignore: unused_local_variable
    final namespaceListOffset = byteReader.readUint32();
    final iconsListOffset = byteReader.readUint32();
    final genericIconsListOffset = byteReader.readUint32();

    if (aliasListOffset > 0) {
      byteReader.offset = aliasListOffset;

      final nAliases = byteReader.readUint32();
      for (int i = 0; i < nAliases && byteReader.offset + 8 <= data.length; i++) {
        final aliasOffset = byteReader.readUint32();
        final mimeOffset = byteReader.readUint32();
        final alias = data.getNullTerminatedString(aliasOffset);
        final mime = data.getNullTerminatedString(mimeOffset);
        _aliases[alias] = mime;
      }
    }

    if (parentListOffset > 0) {
      byteReader.offset = parentListOffset;

      final nEntries = byteReader.readUint32();
      for (int i = 0; i < nEntries && byteReader.offset + 8 <= data.length; i++) {
        final mimeOffset = byteReader.readUint32();
        final parentsOffset = byteReader.readUint32();
        final mime = data.getNullTerminatedString(mimeOffset);

        if (parentsOffset > 0 && parentsOffset < data.length - 4) {
          final parentsByteReader = byteReader.clone(parentsOffset);

          final nParents = parentsByteReader.readUint32();
          final parents = <String>[];
          for (var j = 0; j < nParents && parentsByteReader.offset + 4 <= data.length; j++) {
            final parentOffset = parentsByteReader.readUint32();
            final parent = data.getNullTerminatedString(parentOffset);
            parents.add(parent);
          }

          for (final parent in parents) {
            if (!_subclasses.containsKey(parent)) {
              _subclasses[parent] = [mime];
            } else {
              _subclasses[parent]!.add(mime);
            }
          }
        }
      }
    }

    if (literalListOffset > 0) {
      byteReader.offset = literalListOffset;
      final nLiterals = byteReader.readUint32();

      for (int i = 0; i < nLiterals; i++) {
        final literalOffset = byteReader.readUint32();
        final mimeOffset = byteReader.readUint32();
        final weightAndFlags = byteReader.readUint32();
        final weight = weightAndFlags & 0xFF;
        final caseSensitive = (weightAndFlags & 0x100) != 0;

        final literal = data.getNullTerminatedString(literalOffset);
        final mime = data.getNullTerminatedString(mimeOffset);

        if (caseSensitive) {
          _literals[literal] = MimeData(mime, weight, caseSensitive);
        } else {
          _literals[literal.toLowerCase()] = MimeData(mime, weight, caseSensitive);
        }
      }
    }

    if (globListOffset > 0) {
      byteReader.offset = globListOffset;

      final nGlobs = byteReader.readUint32();
      for (int i = 0; i < nGlobs && byteReader.offset + 12 <= data.length; i++) {
        final globOffset = byteReader.readUint32();
        final mimeOffset = byteReader.readUint32();
        final weightAndFlags = byteReader.readUint32();
        final weight = weightAndFlags & 0xFF;
        final caseSensitive = (weightAndFlags & 0x100) != 0;

        final glob = data.getNullTerminatedString(globOffset);
        final mime = data.getNullTerminatedString(mimeOffset);

        _globs.add(
          GlobPattern(
            Glob(glob, caseSensitive: caseSensitive),
            MimeData(mime, weight, caseSensitive),
          ),
        );
      }
    }

    if (iconsListOffset > 0) {
      byteReader.offset = iconsListOffset;

      final nIcons = byteReader.readUint32();
      for (int i = 0; i < nIcons && byteReader.offset + 8 <= data.length; i++) {
        final mimeOffset = byteReader.readUint32();
        final iconOffset = byteReader.readUint32();
        final mime = data.getNullTerminatedString(mimeOffset);
        final icon = data.getNullTerminatedString(iconOffset);
        if (mime.isNotEmpty && icon.isNotEmpty) {
          _icons[mime] = icon;
        }
      }
    }

    if (genericIconsListOffset > 0) {
      byteReader.offset = genericIconsListOffset;

      final nIcons = byteReader.readUint32();
      for (int i = 0; i < nIcons && byteReader.offset + 8 <= data.length; i++) {
        final mimeOffset = byteReader.readUint32();
        final iconOffset = byteReader.readUint32();
        final mime = data.getNullTerminatedString(mimeOffset);
        final icon = data.getNullTerminatedString(iconOffset);
        if (mime.isNotEmpty && icon.isNotEmpty) {
          _genericIcons[mime] = icon;
        }
      }
    }

    _parseSuffixTree(data, byteReader, reverseSuffixTreeOffset);

    _parseMagicList(data, byteReader, magicListOffset);
  }

  void _parseSuffixTree(Uint8List data, ByteReader byteReader, int offset) {
    if (offset == 0) return;
    byteReader.offset = offset;

    final nRoots = byteReader.readUint32();
    final firstRootOffset = byteReader.readUint32();
    byteReader.offset = firstRootOffset;

    for (int i = 0; i < nRoots; i++) {
      final root = _parseNode(data, byteReader);
      _reverseSuffixTree.add(ReverseTrie(root));
    }
  }

  ReverseTrieNode _parseNode(Uint8List data, ByteReader byteReader) {
    final char = byteReader.readUint32();
    if (char == 0) {
      return _parseLeaf(data, byteReader);
    } else {
      final nChildren = byteReader.readUint32();
      final firstChildrenOffset = byteReader.readUint32();

      final node = ReverseTrieInnerNode(char, []);
      final childrenByteReader = byteReader.clone(firstChildrenOffset);
      for (int i = 0; i < nChildren; i++) {
        final child = _parseNode(data, childrenByteReader);
        node.children.add(child);
      }
      return node;
    }
  }

  ReverseTrieLeaf _parseLeaf(Uint8List data, ByteReader byteReader) {
    final mimeOffset = byteReader.readUint32();
    final weightAndFlags = byteReader.readUint32();

    final weight = weightAndFlags & 0xFF;
    final caseSensitive = (weightAndFlags & 0x100) != 0;

    final mime = data.getNullTerminatedString(mimeOffset);

    return ReverseTrieLeaf(MimeData(mime, weight, caseSensitive));
  }

  void _parseMagicList(Uint8List data, ByteReader byteReader, int offset) {
    if (offset == 0) return;
    byteReader.offset = offset;

    final nMatches = byteReader.readUint32();
    // ignore: unused_local_variable
    final maxExtent = byteReader.readUint32();
    final firstMatchOffset = byteReader.readUint32();
    byteReader.offset = firstMatchOffset;

    for (int i = 0; i < nMatches && byteReader.offset + 16 < data.length; i++) {
      final priority = byteReader.readUint32();
      final mimeOffset = byteReader.readUint32();
      final nMatchlets = byteReader.readUint32();
      final firstMatchletOffset = byteReader.readUint32();

      if (mimeOffset < 0 || mimeOffset >= data.length) {
        continue;
      }
      final mime = data.getNullTerminatedString(mimeOffset);
      if (mime.isNotEmpty) {
        final matchlets = <MagicMatchlet>[];
        final matchletByteReader = byteReader.clone(firstMatchletOffset);
        for (var j = 0; j < nMatchlets && matchletByteReader.offset + 32 < data.length; j++) {
          matchlets.add(_parseMagicMatchlet(data, matchletByteReader));
        }
        _magicRules.add(MagicRule(priority, mime, matchlets));
      }
    }
  }

  MagicMatchlet _parseMagicMatchlet(Uint8List data, ByteReader byteReader) {
    final rangeStart = byteReader.readUint32();
    final rangeLength = byteReader.readUint32();
    final wordSize = byteReader.readUint32();
    final valueLength = byteReader.readUint32();
    final valueOffset = byteReader.readUint32();
    final maskOffset = byteReader.readUint32();
    final nChildren = byteReader.readUint32();
    final firstChildOffset = byteReader.readUint32();

    final valueData = valueOffset >= 0 && valueOffset + valueLength <= data.length
        ? data.sublist(valueOffset, valueOffset + valueLength)
        : Uint8List(0);
    final maskData = maskOffset > 0 && maskOffset + valueLength < data.length
        ? data.sublist(maskOffset, maskOffset + valueLength)
        : null;

    final children = <MagicMatchlet>[];
    final childrenByteReader = byteReader.clone(firstChildOffset);
    for (int i = 0; i < nChildren; i++) {
      children.add(_parseMagicMatchlet(data, childrenByteReader));
    }

    return MagicMatchlet(
      rangeStart: rangeStart,
      rangeLength: rangeLength,
      wordSize: wordSize,
      value: valueData,
      mask: maskData,
      children: children,
    );
  }

  String? _matchMagic(Uint8List data) {
    if (_magicRules.isEmpty) return null;

    final sortedRules = List<MagicRule>.from(_magicRules)
      ..sort((a, b) => b.priority.compareTo(a.priority));

    for (final rule in sortedRules) {
      if (_matchMagicRule(rule, data)) {
        return rule.mimeType;
      }
    }
    return null;
  }

  bool _matchMagicRule(MagicRule rule, Uint8List data) {
    for (final matchlet in rule.matchlets) {
      if (_matchMatchlet(matchlet, data)) {
        if (matchlet.children.isEmpty) return true;
        for (final child in matchlet.children) {
          if (_matchMatchlet(child, data)) return true;
        }
      }
    }
    return false;
  }

  bool _matchMatchlet(MagicMatchlet matchlet, Uint8List data) {
    final start = matchlet.rangeStart;
    final length = matchlet.rangeLength;

    if (start >= data.length) return false;

    final end = start + length;
    final actualLength = end > data.length ? data.length - start : length;

    final fileData = Uint8List.sublistView(data, start, start + actualLength);

    if (matchlet.mask != null && fileData.length >= matchlet.rangeLength) {
      final mask = matchlet.mask!;
      for (int i = 0; i < matchlet.value.length; i++) {
        final maskedData = fileData[i] & mask[i];
        if (maskedData != matchlet.value[i]) return false;
      }
    } else {
      if (fileData.length != matchlet.value.length) return false;
      for (int i = 0; i < matchlet.value.length; i++) {
        if (fileData[i] != matchlet.value[i]) return false;
      }
    }
    return true;
  }

  String? resolveAlias(String alias) {
    String? result;
    while (true) {
      final a = _aliases[alias];
      if (a == null) {
        return result;
      }
      alias = a;
      if (a == result) {
        return result;
      }
      result = a;
    }
  }

  List<String> getSubclasses(String parentMime) => _subclasses[parentMime] ?? [];

  String? getIcon(String mimeType) => _icons[mimeType];

  String? getGenericIcon(String mimeType) => _genericIcons[mimeType];

  MimeEntry? getMimeEntry(String mime) {
    return MimeEntry(
      mime: mime,
      subclasses: getSubclasses(mime),
      icon: getIcon(mime),
      genericIcon: getGenericIcon(mime),
    );
  }
}

class SharedMimeInfo {
  static Future<MimeDatabase> open() async {
    final directories = [
      ...xdg_dir.dataDirs.reversed,
      xdg_dir.dataHome,
    ].map((d) => Directory(path.join(d.path, 'mime')));

    final dbs = <MimeDatabase>[];
    for (final dir in directories) {
      if (dir.existsSync()) {
        final db = await MimeDatabase.fromDirectory(dir);
        dbs.add(db);
      }
    }

    if (dbs.isEmpty) return MimeDatabase.empty();
    if (dbs.length == 1) return dbs.first;

    return _mergeDatabases(dbs);
  }

  static MimeDatabase _mergeDatabases(List<MimeDatabase> dbs) {
    final merged = MimeDatabase.empty();
    for (final db in dbs) {
      merged._globs.addAll(db._globs);
      merged._subclasses.addAll(db._subclasses);
      merged._aliases.addAll(db._aliases);
      merged._icons.addAll(db._icons);
      merged._genericIcons.addAll(db._genericIcons);
      merged._magicRules.addAll(db._magicRules);
      merged._reverseSuffixTree.addAll(db._reverseSuffixTree);
      merged._literals.addAll(db._literals);
    }
    return merged;
  }

  static MimeDatabase mergeDatabases(List<MimeDatabase> dbs) => _mergeDatabases(dbs);
}
