import 'mime_types.dart';

class ReverseTrie {
  final ReverseTrieNode root;

  ReverseTrie(this.root);

  MimeData? match(String name) {
    final matches = root.match(name.codeUnits);
    if (matches.isEmpty) {
      return null;
    }
    if (matches.length == 1) {
      return matches[0];
    }
    MimeData max = matches[0];
    for (final match in matches.sublist(1)) {
      if (max.weight < match.weight) {
        max = match;
      }
    }
    return max;
  }
}

sealed class ReverseTrieNode {
  List<MimeData> match(List<int> chars);
}

class ReverseTrieInnerNode extends ReverseTrieNode {
  final int char;
  final List<ReverseTrieNode> children;

  ReverseTrieInnerNode(this.char, this.children);

  @override
  List<MimeData> match(List<int> chars) {
    if (chars.isEmpty) {
      return [];
    }
    if (chars.last != char) {
      return [];
    }
    chars = chars.sublist(0, chars.length - 1);
    final matches = <MimeData>[];
    for (final child in children) {
      matches.addAll(child.match(chars));
    }
    return matches;
  }
}

class ReverseTrieLeaf extends ReverseTrieNode {
  final MimeData data;

  ReverseTrieLeaf(this.data);

  @override
  List<MimeData> match(List<int> _) {
    return [data];
  }
}
