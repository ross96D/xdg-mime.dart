import 'dart:typed_data';

class ByteReader {
  ByteData data;
  int offset;

  ByteReader(this.data) : offset = 0;

  /// The (possibly negative) integer represented by the byte at the
  /// specified [offset] in this object, in two's complement binary
  /// representation.
  ///
  /// The return value will be between -128 and 127, inclusive.
  int readInt8() {
    final response = data.getInt8(offset);
    offset += 1;
    return response;
  }

  /// The positive integer represented by the byte at the specified
  /// [offset] in this object, in unsigned binary form.
  ///
  /// The return value will be between 0 and 255, inclusive.
  ///
  /// The [offset] must be non-negative, and
  /// less than the length of this object.
  int readUint8() {
    final response = data.getUint8(offset);
    offset += 1;
    return response;
  }

  /// The (possibly negative) integer represented by the two bytes at
  /// the specified [offset] in this object, in two's complement binary
  /// form.
  ///
  /// The return value will be between -2<sup>15</sup> and 2<sup>15</sup> - 1,
  /// inclusive.
  int readInt16([Endian endian = Endian.big]) {
    final response = data.getInt16(offset, endian);
    offset += 2;
    return response;
  }

  /// The positive integer represented by the two bytes starting
  /// at the specified [offset] in this object, in unsigned binary
  /// form.
  ///
  /// The return value will be between 0 and  2<sup>16</sup> - 1, inclusive.
  int readUint16([Endian endian = Endian.big]) {
    final response = data.getUint16(offset, endian);
    offset += 2;
    return response;
  }

  /// The (possibly negative) integer represented by the four bytes at
  /// the specified [offset] in this object, in two's complement binary
  /// form.
  ///
  /// The return value will be between -2<sup>31</sup> and 2<sup>31</sup> - 1,
  /// inclusive.
  int readInt32([Endian endian = Endian.big]) {
    final response = data.getInt32(offset, endian);
    offset += 4;
    return response;
  }

  /// The positive integer represented by the four bytes starting
  /// at the specified [offset] in this object, in unsigned binary
  /// form.
  ///
  /// The return value will be between 0 and  2<sup>32</sup> - 1, inclusive.
  int readUint32([Endian endian = Endian.big]) {
    final response = data.getUint32(offset, endian);
    offset += 4;
    return response;
  }

  /// The (possibly negative) integer represented by the eight bytes at
  /// the specified [offset] in this object, in two's complement binary
  /// form.
  ///
  /// The return value will be between -2<sup>63</sup> and 2<sup>63</sup> - 1,
  /// inclusive.
  int readInt64([Endian endian = Endian.big]) {
    final response = data.getInt64(offset, endian);
    offset += 8;
    return response;
  }

  /// The positive integer represented by the eight bytes starting
  /// at the specified [offset] in this object, in unsigned binary
  /// form.
  ///
  /// The return value will be between 0 and  2<sup>64</sup> - 1, inclusive.
  int readUint64([Endian endian = Endian.big]) {
    final response = data.getUint64(offset, endian);
    offset += 8;
    return response;
  }

  /// The floating point number represented by the four bytes at
  /// the specified [offset] in this object, in IEEE 754
  /// single-precision binary floating-point format (binary32).
  double getFloat32([Endian endian = Endian.big]) {
    final response = data.getFloat32(offset, endian);
    offset += 4;
    return response;
  }

  /// The floating point number represented by the eight bytes at
  /// the specified [offset] in this object, in IEEE 754
  /// double-precision binary floating-point format (binary64).
  double getFloat64([Endian endian = Endian.big]) {
    final response = data.getFloat64(offset, endian);
    offset += 8;
    return response;
  }

  ByteReader clone([int? offset]) {
    final reader = ByteReader(data);
    reader.offset = offset ?? this.offset;
    return reader;
  }
}
