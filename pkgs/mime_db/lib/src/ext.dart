import 'dart:convert';
import 'dart:typed_data';

extension UintExt on Uint8List {
  String getNullTerminatedString(int offset) {
    if (offset >= length || offset < 0) {
      throw ArgumentError("invalid offset $offset. Should be between 0 and $length", "offset");
    }
    int end = offset;
    while (end < length && this[end] != 0) {
      end++;
    }
    return utf8.decode(sublist(offset, end));
  }
}
