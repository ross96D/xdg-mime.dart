const _escaped = '\x00';

const _singleCodes = {'%f', '%u', '%c', '%k'};
const _multiCodes = {'%F', '%U', '%i'};
const _deprecated = {'%d', '%D', '%n', '%N', '%v', '%m'};

List<String> expandExec(
  String exec, {
  List<String> files = const [],
  List<String> urls = const [],
  String? icon,
  String? name,
  String? desktopFilePath,
}) {
  final tokens = _tokenize(exec);
  return _expand(tokens, files, urls, icon, name, desktopFilePath);
}

List<String> _tokenize(String exec) {
  final tokens = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;

  for (var i = 0; i < exec.length; i++) {
    final ch = exec[i];
    if (inQuotes) {
      if (ch == '"') {
        inQuotes = false;
      } else if (ch == '\\' && i + 1 < exec.length) {
        final next = exec[i + 1];
        if (next == '"' || next == '\\' || next == '\$' || next == '`') {
          buf.write(next);
          i++;
        } else {
          buf.write(ch);
        }
      } else {
        buf.write(ch);
      }
    } else {
      if (ch == '"') {
        inQuotes = true;
      } else if (ch == ' ') {
        if (buf.isNotEmpty) {
          tokens.add(buf.toString());
          buf.clear();
        }
      } else {
        buf.write(ch);
      }
    }
  }
  if (buf.isNotEmpty) {
    tokens.add(buf.toString());
  }
  return tokens;
}

List<String> _expand(
  List<String> tokens,
  List<String> files,
  List<String> urls,
  String? icon,
  String? name,
  String? desktopFilePath,
) {
  final result = <String>[];
  String? seenFileCode;
  final noFilesUrls = files.isEmpty && urls.isEmpty;

  for (final token in tokens) {
    if (_singleCodes.contains(token)) {
      seenFileCode = _checkFileCode(seenFileCode, token);
      switch (token) {
        case '%f':
          if (noFilesUrls) continue;
          result.add(files.first);
        case '%u':
          if (noFilesUrls) continue;
          result.add(urls.first);
        case '%c':
          result.add(name ?? '');
        case '%k':
          result.add(desktopFilePath ?? '');
      }
      continue;
    }

    if (_multiCodes.contains(token)) {
      seenFileCode = _checkFileCode(seenFileCode, token);
      switch (token) {
        case '%F':
          if (noFilesUrls) continue;
          result.addAll(files);
        case '%U':
          if (noFilesUrls) continue;
          result.addAll(urls);
        case '%i':
          if (icon != null && icon.isNotEmpty) result.addAll(['--icon', icon]);
      }
      continue;
    }

    if (_deprecated.contains(token)) {
      continue;
    }

    if (token == '%%') {
      result.add('%');
      continue;
    }

    if (token.contains('%f')) {
      seenFileCode = _checkFileCode(seenFileCode, '%f');
    }
    if (token.contains('%u')) {
      seenFileCode = _checkFileCode(seenFileCode, '%u');
    }
    result.add(_expandEmbedded(token, files, urls, name,
        desktopFilePath, noFilesUrls));
  }

  return result;
}

String _expandEmbedded(
  String token,
  List<String> files,
  List<String> urls,
  String? name,
  String? desktopFilePath,
  bool noFilesUrls,
) {
  var result = token.replaceAll('%%', _escaped);

  for (final c in ['%F', '%U', '%i']) {
    if (result.contains(c)) {
      throw Exception(
          'Field code $c must be used as a standalone argument in "$token"');
    }
  }

  _checkUnknownCodes(result);

  if (noFilesUrls) {
    result = result.replaceAll('%f', '').replaceAll('%u', '');
  } else {
    result = result.replaceAll('%f', files.firstOrNull ?? '');
    result = result.replaceAll('%u', urls.firstOrNull ?? '');
  }
  result = result.replaceAll('%c', name ?? '');
  result = result.replaceAll('%k', desktopFilePath ?? '');
  for (final c in _deprecated) {
    result = result.replaceAll(c, '');
  }

  return result.replaceAll(_escaped, '%');
}

void _checkUnknownCodes(String token) {
  for (var i = 0; i < token.length - 1; i++) {
    if (token[i] != '%') continue;
    final code = token.substring(i, i + 2);
    if (code == _escaped + _escaped) {
      i++;
      continue;
    }
    if (code == '%%') continue;
    if (_singleCodes.contains(code)) continue;
    if (_multiCodes.contains(code)) continue;
    if (_deprecated.contains(code)) continue;
    throw Exception('Unknown field code: $code in "$token"');
  }
}

String? _checkFileCode(String? seen, String code) {
  if (seen != null) {
    throw Exception('Multiple file/URL field codes: $seen and $code');
  }
  return code;
}

extension<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
