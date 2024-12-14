import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TTSServiceAll {
  TTSServiceAll(this.apiKey);

  final String apiKey;

  Stream<Uint8List> tts(String url, Map<String, dynamic> payload) async* {
    final payloadData = utf8.encode(jsonEncode(payload));
    // Create a StreamedRequest for chunked streaming
    final request = http.StreamedRequest('POST', Uri.parse(url))
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..headers['Content-Length'] = payloadData.length.toString()
      ..headers['Transfer-Encoding'] = 'chunked';

    // Add payload to the request
    try {
      request.sink.add(payloadData);
      unawaited(request.sink.close());
    } catch (e) {
      debugPrint('Error during request setup: $e');
      rethrow;
    }

    // Send the request
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception(
          'Failed to fetch stream. Status code: ${response.statusCode}');
    }

    /// Since the chunks size coming from OpenAI could be really small and they
    /// can be odd, here we are using a buffer. When the buffer reaches the
    /// [chunkSize] size, we yield the bytes so we are sure that we deliver
    /// an even number of bytes of a consistent size.
    final buffer = BytesBuilder();
    var remainder = Uint8List(0);
    const chunkSize = 1024 * 2; // 2 KB of audio data
    var count = 0;
    // Read and yield chunks from the response stream
    await for (final chunk in response.stream) {
      buffer.add(chunk);
      count++;
      debugPrint('YIELD count: $count  buffer: ${buffer.length} bytes');

      while (buffer.length >= chunkSize) {
        final bufferBytes = buffer.toBytes();
        final chunk = Uint8List.sublistView(bufferBytes, 0, chunkSize);
        debugPrint('Chunk: ${chunk.length} bytes');
        yield chunk;

        remainder = Uint8List.sublistView(bufferBytes, chunkSize);
        buffer
          ..clear()
          ..add(remainder);
      }
    }
    if (remainder.isNotEmpty) yield remainder;
  }
}
