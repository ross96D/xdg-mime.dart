class MimeNode {
  final String mime;
  final List<MimeNode> parents = [];
  final List<MimeNode> children = [];

  MimeNode(this.mime);
}

class MimeFamilyGraph {
  final List<MimeNode> _nodes = [];

  MimeFamilyGraph();

  MimeNode _getOrAddNode(String mime) {
    for (final node in _nodes) {
      if (node.mime == mime) return node;
    }
    final node = MimeNode(mime);
    _nodes.add(node);
    return node;
  }

  void addParentChild(String parentMime, String childMime) {
    final parent = _getOrAddNode(parentMime);
    final child = _getOrAddNode(childMime);
    parent.children.add(child);
    child.parents.add(parent);
  }

  List<MimeNode> getParents(String mime) {
    for (final node in _nodes) {
      if (node.mime == mime) return node.parents;
    }
    return [];
  }

  List<MimeNode> getChildren(String mime) {
    for (final node in _nodes) {
      if (node.mime == mime) return node.children;
    }
    return [];
  }

  List<String> getAncestors(String mime) {
    final ancestors = <String>[];
    final visited = <String>{};
    var queue = getParents(mime).toList();
    while (queue.isNotEmpty) {
      final next = <MimeNode>[];
      for (final parent in queue) {
        if (!visited.contains(parent.mime)) {
          visited.add(parent.mime);
          ancestors.add(parent.mime);
          next.addAll(parent.parents);
        }
      }
      queue = next;
    }
    return ancestors;
  }

  List<String> getDescendants(String mime) {
    final descendants = <String>[];
    final visited = <String>{};
    var queue = getChildren(mime).toList();
    while (queue.isNotEmpty) {
      final next = <MimeNode>[];
      for (final child in queue) {
        if (!visited.contains(child.mime)) {
          visited.add(child.mime);
          descendants.add(child.mime);
          next.addAll(child.children);
        }
      }
      queue = next;
    }
    return descendants;
  }

  void merge(MimeFamilyGraph other) {
    for (final node in other._nodes) {
      for (final parent in node.parents) {
        addParentChild(parent.mime, node.mime);
      }
    }
  }

  List<MimeNode> get nodes => _nodes;
}
