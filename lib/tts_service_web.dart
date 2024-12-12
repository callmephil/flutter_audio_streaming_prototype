import 'dart:convert';
import 'dart:typed_data';

import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

@JS('fetch')
external dynamic fetchJs(dynamic url, dynamic options);

class TTSServiceWeb {
  final String apiKey;

  TTSServiceWeb(this.apiKey);

  Stream<Uint8List> tts(String url, Map<String, dynamic> payload) async* {
    final options = js_util.jsify({
      'method': 'POST',
      'headers': {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
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

    while (true) {
      final result =
          await js_util.promiseToFuture(js_util.callMethod(reader, 'read', []));
      final done = js_util.getProperty(result, 'done') as bool;
      if (done) break;

      final chunk = js_util.getProperty(result, 'value');
      yield Uint8List.fromList(List<int>.from(chunk));
    }
  }
}
