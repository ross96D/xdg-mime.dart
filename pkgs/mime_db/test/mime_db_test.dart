import 'dart:typed_data';
import 'package:xdg_mime_db/xdg_mime_db.dart';
import 'package:test/test.dart';

void main() {
  group('MagicMatchlet swap logic', () {
    test('little endian wordSize=2 swaps bytes in each word', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 4,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
        wordSize: 2,
        host: Endian.little,
      );
      expect(matchlet.value, [0x02, 0x01, 0x04, 0x03]);
    });

    test('little endian wordSize=4 swaps bytes in each word', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 8,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08]),
        wordSize: 4,
        host: Endian.little,
      );
      expect(matchlet.value, [0x04, 0x03, 0x02, 0x01, 0x08, 0x07, 0x06, 0x05]);
    });

    test('little endian partial last word is not swapped', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 5,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04, 0x05]),
        wordSize: 2,
        host: Endian.little,
      );
      expect(matchlet.value, [0x02, 0x01, 0x04, 0x03, 0x05]);
    });

    test('big endian wordSize=2 does not swap', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 4,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
        wordSize: 2,
        host: Endian.big,
      );
      expect(matchlet.value, [0x01, 0x02, 0x03, 0x04]);
    });

    test('wordSize=1 does not swap', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 4,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
        wordSize: 1,
        host: Endian.little,
      );
      expect(matchlet.value, [0x01, 0x02, 0x03, 0x04]);
    });

    test('little endian swaps mask when same length as value', () {
      final matchlet = MagicMatchlet(
        rangeStart: 0,
        rangeLength: 4,
        value: Uint8List.fromList([0x01, 0x02, 0x03, 0x04]),
        wordSize: 2,
        mask: Uint8List.fromList([0xFF, 0xFF, 0xFF, 0xFF]),
        host: Endian.little,
      );
      expect(matchlet.value, [0x02, 0x01, 0x04, 0x03]);
      expect(matchlet.mask, [0xFF, 0xFF, 0xFF, 0xFF]);
    });
  });
}
