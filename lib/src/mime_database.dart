import 'dart:io';
import 'dart:typed_data';

import 'package:mime_db/src/byte_reader.dart';
import 'package:mime_db/src/ext.dart';
import 'package:mime_db/src/mime_types.dart';
import 'package:path/path.dart' as path;

export 'mime_database.dart';

abstract interface class _IMimeDatabase {
  String? getMimeTypeFromFilename(String filename, {Uint8List? data});

  /// Returns the MIME type for [extension], which should be with the leading dot (e.g. ".txt", not "txt").
  String? getMimeType(String extension, {Uint8List? data});

  /// Returns the MIME type for [extension], which should be with the leading dot (e.g. ".txt", not "txt").
  String? lookup(String extension);

  String? resolveAlias(String alias);

  List<String> getSubclasses(String mimeType);

  String? getIcon(String mimeType);

  String? getGenericIcon(String mimeType);

  MimeTypeEntry? getMimeTypeInfo(String mimeType);
}

class MimeDatabase implements _IMimeDatabase {
  final Map<String, MimeTypeEntry> _types = {};
  final Map<String, String> _aliases = {};
  final Map<String, List<String>> _subclasses = {};
  final Map<String, String> _icons = {};
  final Map<String, String> _genericIcons = {};
  final List<GlobPattern> _globs = [];
  final List<MagicRule> _magicRules = [];
  final String? _basePath;

  List<GlobPattern> get globs => _globs;
  List<MagicRule> get magicRules => _magicRules;

  MimeDatabase._([this._basePath]);

  MimeDatabase.empty() : _basePath = null;

  static Future<MimeDatabase> fromDirectory(String dir) async {
    final db = MimeDatabase._(dir);
    await db._load();
    return db;
  }

  Future<void> _load() async {
    if (_basePath == null) return;

    final cacheFile = path.join(_basePath, 'mime.cache');
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
    // ignore: unused_local_variable
    final literalListOffset = byteReader.readUint32();
    // ignore: unused_local_variable
    final reverseSuffixTreeOffset = byteReader.readUint32();
    final globListOffset = byteReader.readUint32();
    final magicListOffset = byteReader.readUint32();
    // ignore: unused_local_variable
    final namespaceListOffset = byteReader.readUint32();
    final iconsListOffset = byteReader.readUint32();
    final genericIconsListOffset = byteReader.readUint32();

    if (aliasListOffset > 0 && aliasListOffset < data.length - 4) {
      byteReader.offset = aliasListOffset;

      final nAliases = byteReader.readUint32();
      for (var i = 0; i < nAliases && byteReader.offset + 8 <= data.length; i++) {
        final aliasOffset = byteReader.readUint32();
        final mimeOffset = byteReader.readUint32();
        final alias = data.getNullTerminatedString(aliasOffset);
        final mime = data.getNullTerminatedString(mimeOffset);
        _aliases[alias] = mime;
      }
    }

    if (parentListOffset > 0 && parentListOffset < data.length - 4) {
      byteReader.offset = parentListOffset;

      final nEntries = byteReader.readUint32();
      for (var i = 0; i < nEntries && byteReader.offset + 8 <= data.length; i++) {
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
          if (mime.isNotEmpty) _subclasses[mime] = parents;
        }
      }
    }

    if (globListOffset > 0 && globListOffset < data.length - 4) {
      byteReader.offset = globListOffset;

      final nGlobs = byteReader.readUint32();
      for (var i = 0; i < nGlobs && byteReader.offset + 12 <= data.length; i++) {
        final globOffset = byteReader.readUint32();
        final mimeOffset = byteReader.readUint32();
        final weightAndFlags = byteReader.readUint32();
        final glob = data.getNullTerminatedString(globOffset);
        final mime = data.getNullTerminatedString(mimeOffset);
        if (glob.isNotEmpty && mime.isNotEmpty) {
          final weight = weightAndFlags & 0xFF;
          final caseSensitive = (weightAndFlags & 0x100) != 0;
          _globs.add(GlobPattern(glob, mime, weight, caseSensitive));
        }
      }
    }

    if (iconsListOffset > 0 && iconsListOffset < data.length - 4) {
      byteReader.offset = iconsListOffset;

      final nIcons = byteReader.readUint32();
      for (var i = 0; i < nIcons && byteReader.offset + 8 <= data.length; i++) {
        final mimeOffset = byteReader.readUint32();
        final iconOffset = byteReader.readUint32();
        final mime = data.getNullTerminatedString(mimeOffset);
        final icon = data.getNullTerminatedString(iconOffset);
        if (mime.isNotEmpty && icon.isNotEmpty) {
          _icons[mime] = icon;
        }
      }
    }

    if (genericIconsListOffset > 0 && genericIconsListOffset < data.length - 4) {
      byteReader.offset = genericIconsListOffset;

      final nIcons = byteReader.readUint32();
      for (var i = 0; i < nIcons && byteReader.offset + 8 <= data.length; i++) {
        final mimeOffset = byteReader.readUint32();
        final iconOffset = byteReader.readUint32();
        final mime = data.getNullTerminatedString(mimeOffset);
        final icon = data.getNullTerminatedString(iconOffset);
        if (mime.isNotEmpty && icon.isNotEmpty) {
          _genericIcons[mime] = icon;
        }
      }
    }

    _parseMagicList(data, byteReader, magicListOffset);

    _parseMimeTypes(data);
  }

  void _parseMagicList(Uint8List data, ByteReader byteReader, int offset) {
    if (offset == 0 || offset + 8 > data.length) return;
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

  void _parseMimeTypes(Uint8List data) {
    final subdirs = [
      'application',
      'audio',
      'image',
      'inode',
      'message',
      'model',
      'multipart',
      'text',
      'video',
      'x-content',
      'x-scheme-handler',
    ];
    for (final subdir in subdirs) {
      _loadMimeTypeDir(subdir, data);
    }
  }

  void _loadMimeTypeDir(String subdir, Uint8List data) {
    // Would need to read XML files from MEDIA/SUBTYPE.xml paths
    // For now this is a placeholder - the cache file has the key data
  }

  @override
  String? getMimeType(String extension, {Uint8List? data}) {
    assert(extension.isNotEmpty);
    final match = _matchGlob('*$extension');
    if (match != null) return match;

    if (data != null && data.isNotEmpty) {
      final magicMatch = _matchMagic(data);
      if (magicMatch != null) return magicMatch;
    }

    return null;
  }

  String? _matchMagic(Uint8List data) {
    if (_magicRules.isEmpty) return null;

    final sortedRules = List<MagicRule>.from(_magicRules)..sort((a, b) => b.priority.compareTo(a.priority));

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
      for (var i = 0; i < matchlet.value.length; i++) {
        final maskedData = fileData[i] & mask[i];
        if (maskedData != matchlet.value[i]) return false;
      }
    } else {
      if (fileData.length != matchlet.value.length) return false;
      for (var i = 0; i < matchlet.value.length; i++) {
        if (fileData[i] != matchlet.value[i]) return false;
      }
    }
    return true;
  }

  String? _matchGlob(String name) {
    final matches = _globs.where((g) => g.match(name)).toList();
    if (matches.isEmpty) return null;

    matches.sort((a, b) {
      final weightCompare = b.weight.compareTo(a.weight);
      if (weightCompare != 0) return weightCompare;
      return b.pattern.length.compareTo(a.pattern.length);
    });

    final best = matches.first;
    final othersSameMime = matches.where((m) => m.mimeType == best.mimeType).length;
    final othersSameWeight = matches.where((m) => m.weight == best.weight && m.mimeType != best.mimeType).length;

    if (othersSameMime == matches.length) {
      return best.mimeType;
    }
    if (othersSameMime > 1 || othersSameWeight > 0) {
      return null;
    }
    return best.mimeType;
  }

  @override
  String? lookup(String extension) => getMimeType(extension);

  @override
  String? resolveAlias(String alias) => _aliases[alias];

  @override
  List<String> getSubclasses(String mimeType) => _subclasses[mimeType] ?? [];

  @override
  String? getIcon(String mimeType) => _icons[mimeType];

  @override
  String? getGenericIcon(String mimeType) => _genericIcons[mimeType];

  @override
  MimeTypeEntry? getMimeTypeInfo(String mimeType) => _types[mimeType];

  @override
  String? getMimeTypeFromFilename(String filename, {Uint8List? data}) {
    return getMimeType(path.extension(filename), data: data);
  }
}

class SharedMimeInfo {
  static Future<MimeDatabase> open() async {
    final dataHome =
        Platform.environment['XDG_DATA_HOME'] ?? path.join(Platform.environment['HOME'] ?? '', '.local', 'share');
    final dataDirs = (Platform.environment['XDG_DATA_DIRS'] ?? '/usr/share')
        .split(':')
        .where((d) => d.isNotEmpty)
        .toList();

    final paths = [dataHome, ...dataDirs].map((d) => path.join(d, 'mime')).toList();

    final dbs = <MimeDatabase>[];
    for (final p in paths) {
      if (await Directory(p).exists()) {
        final db = await MimeDatabase.fromDirectory(p);
        dbs.add(db);
      }
    }

    if (dbs.isEmpty) return MimeDatabase.empty();
    if (dbs.length == 1) return dbs.first;

    return _mergeDatabases(dbs);
  }

  static MimeDatabase _mergeDatabases(List<MimeDatabase> dbs) {
    final merged = MimeDatabase.empty();
    final deletedGlobs = <String, Set<String>>{};
    final deletedMagic = <String>{};

    for (final db in dbs) {
      for (final g in db.globs) {
        if (g.pattern == '__NOGLOBS__') {
          deletedGlobs[g.mimeType] ??= {};
          deletedGlobs[g.mimeType]!.add('__ALL__');
          merged.globs.removeWhere((e) => e.mimeType == g.mimeType);
          continue;
        }

        if (deletedGlobs[g.mimeType]?.contains('__ALL__') == true) continue;
        if (deletedGlobs[g.mimeType]?.contains(g.pattern) == true) continue;

        final existing = merged.globs.indexWhere((e) => e.pattern == g.pattern && e.mimeType == g.mimeType);
        if (existing == -1) {
          merged.globs.add(g);
        }
      }

      for (final alias in db._aliases.entries) {
        if (!merged._aliases.containsKey(alias.key)) {
          merged._aliases[alias.key] = alias.value;
        }
      }

      for (final entry in db._subclasses.entries) {
        if (!merged._subclasses.containsKey(entry.key)) {
          merged._subclasses[entry.key] = entry.value;
        }
      }

      for (final icon in db._icons.entries) {
        if (!merged._icons.containsKey(icon.key)) {
          merged._icons[icon.key] = icon.value;
        }
      }

      for (final icon in db._genericIcons.entries) {
        if (!merged._genericIcons.containsKey(icon.key)) {
          merged._genericIcons[icon.key] = icon.value;
        }
      }

      for (final rule in db.magicRules) {
        if (rule.matchlets.any((m) => _isNomagicMatchlet(m))) {
          deletedMagic.add(rule.mimeType);
        }
      }
    }

    if (deletedMagic.isNotEmpty) {
      merged._magicRules.removeWhere((r) => deletedMagic.contains(r.mimeType));
    }

    merged.globs.sort((a, b) => b.weight.compareTo(a.weight));

    return merged;
  }

  static MimeDatabase mergeDatabases(List<MimeDatabase> dbs) => _mergeDatabases(dbs);

  static bool _isNomagicMatchlet(MagicMatchlet m) {
    final nomagic = [0x5F, 0x5F, 0x4E, 0x4F, 0x4D, 0x41, 0x47, 0x49, 0x43, 0x5F, 0x5F];
    if (m.value.length == nomagic.length) {
      for (var i = 0; i < nomagic.length; i++) {
        if (m.value[i] != nomagic[i]) return false;
      }
      return true;
    }
    return false;
  }
}
