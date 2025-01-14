import 'dart:typed_data';

extension StreamChunkingExtension on Stream<Uint8List> {
  /// Extension method to chunk the stream into desired buffer sizes.
  Stream<Uint8List> chunked(int chunkSize) async* {
    final buffer = BytesBuilder();
    Uint8List remainder = Uint8List(0);

    await for (final chunk in this) {
      buffer.add(chunk);

      while (buffer.length >= chunkSize) {
        final bufferBytes = buffer.toBytes();
        yield Uint8List.sublistView(bufferBytes, 0, chunkSize);

        remainder = Uint8List.sublistView(bufferBytes, chunkSize);
        buffer
          ..clear()
          ..add(remainder);
      }
    }

    // Emit the remaining bytes if any
    if (remainder.isNotEmpty) yield remainder;
  }
}
