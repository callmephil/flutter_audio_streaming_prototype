import 'dart:convert';
import 'dart:typed_data';

import 'package:example/services/tts_service_base.dart';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

@JS('AbortController')
external dynamic get abortControllerConstructor;

@JS('fetch')
external dynamic fetchJs(dynamic url, dynamic options);

class TTSService extends TTSServiceBase {
  dynamic _abortController;

  TTSService(super.apiKey);

  void _createCancelToken() {
    _abortController = js_util.callConstructor(abortControllerConstructor, []);
  }

  @override
  void cancel() {
    if (_abortController != null) {
      js_util.callMethod(_abortController, 'abort', []);
      _abortController = null;
    }
  }

  @override
  Stream<Uint8List> tts(String url, Map<String, dynamic> payload) async* {
    _createCancelToken();

    final options = js_util.jsify({
      'method': 'POST',
      'headers': {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
        'Transfer-Encoding': 'chunked',
        'Cache-Control': 'no-cache',
      },
      'body': jsonEncode(payload),
      'signal': js_util.getProperty(_abortController, 'signal'),
    });

    try {
      final response = await js_util.promiseToFuture(fetchJs(url, options));
      final status = js_util.getProperty(response, 'status') as int;
      if (status != 200) {
        throw Exception('Failed to fetch stream. Status code: $status');
      }

      final body = js_util.getProperty(response, 'body');
      final reader = js_util.callMethod(body, 'getReader', []);

      while (true) {
        final result = await js_util
            .promiseToFuture(js_util.callMethod(reader, 'read', []));

        final done = js_util.getProperty(result, 'done') as bool;
        if (done) break;

        final value = js_util.getProperty(result, 'value');
        yield Uint8List.fromList(List<int>.from(value));
      }
    } finally {
      _abortController = null;
    }
  }
}
