import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

@JS('fetch')
external dynamic fetchJs(dynamic url, dynamic options);

class TTSService {
  final String apiKey;

  TTSService(this.apiKey);

  Stream<Uint8List> tts(String url, Map<String, dynamic> payload,
      {int chunkSize = 1024 * 32}) async* {
    final options = js_util.jsify({
      'method': 'POST',
      'headers': {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Transfer-Encoding': 'chunked',
        'Cache-Control': 'no-cache',
      },
      'body': jsonEncode(payload),
    });

    final response = await js_util.promiseToFuture(fetchJs(url, options));
    final status = js_util.getProperty(response, 'status') as int;
    if (status != 200) {
      throw Exception('Failed to fetch stream. Status code: $status');
    }

    final body = js_util.getProperty(response, 'body');
    final reader = js_util.callMethod(body, 'getReader', []);

    /// Since the chunks size coming from OpenAI could be really small and they
    /// can be odd, here we are using a buffer. When the buffer reaches the
    /// [chunkSize] size, we yield the bytes so we are sure that we deliver
    /// an even number of bytes of a consistent size.
    final buffer = BytesBuilder();
    var remainder = Uint8List(0);
    var count = 0;

    while (true) {
      final result =
          await js_util.promiseToFuture(js_util.callMethod(reader, 'read', []));
      final done = js_util.getProperty(result, 'done') as bool;
      if (done) break;

      final chunk = js_util.getProperty(result, 'value');
      buffer.add(List<int>.from(chunk));
      count++;
      debugPrint('YIELD count: $count  buffer: ${buffer.length} bytes');

      while (buffer.length >= chunkSize) {
        final bufferBytes = buffer.toBytes();
        final chunk = Uint8List.sublistView(bufferBytes, 0, chunkSize);
        // debugPrint('Chunk: ${chunk.length} bytes');
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
