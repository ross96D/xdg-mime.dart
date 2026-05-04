import 'dart:typed_data';

enum ParseErrorKind {
  utf8Error,
  unexpectedToken,
  incompleteInput,
  missingRequiredField,
  invalidFieldValue,
}

class ParseError {
  final ParseErrorKind kind;
  final Uint8List bytes;
  final String message;

  const ParseError._(this.kind, this.bytes, this.message);

  factory ParseError.utf8(Uint8List bytes, String message) {
    return ParseError._(ParseErrorKind.utf8Error, bytes, message);
  }

  factory ParseError.unexpected(String message, [Uint8List? bytes]) {
    return ParseError._(ParseErrorKind.unexpectedToken, bytes ?? Uint8List(0), message);
  }

  factory ParseError.incomplete(String message, [Uint8List? bytes]) {
    return ParseError._(ParseErrorKind.incompleteInput, bytes ?? Uint8List(0), message);
  }

  factory ParseError.missingRequiredField(String field) {
    return ParseError._(.missingRequiredField, Uint8List(0), "Missing required field $field");
  }

  factory ParseError.invalidFieldValue(
    String field,
    String value, [
    List<String> expectedValues = const [],
  ]) {
    return ParseError._(
      .missingRequiredField,
      Uint8List(0),
      "Field $field has an invalid value $value."
      "${expectedValues.isNotEmpty ? ' Expected values are ${expectedValues.join(', ')}.' : ''}",
    );
  }

  @override
  String toString() => 'ParseError($kind: $message)';
}
