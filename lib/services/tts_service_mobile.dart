import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:example/services/tts_service_base.dart';

class TTSService extends TTSServiceBase {
  final Dio _dio;
  CancelToken? _cancelToken;

  TTSService(super.apiKey)
      : _dio = Dio(
          BaseOptions(
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            responseType: ResponseType.stream,
          ),
        );

  void _createCancelToken() {
    _cancelToken = CancelToken();
  }

  @override
  Stream<Uint8List> tts(String url, Map<String, dynamic> payload) {
    final payloadData = utf8.encode(jsonEncode(payload));
    final contentLength = payloadData.length;
    final controller = StreamController<List<int>>();

    _createCancelToken();

    _dio
        .post(
      url,
      data: Stream.fromIterable([payloadData]),
      options: Options(
        headers: {
          'Content-Length': contentLength.toString(),
          'Transfer-Encoding': 'chunked',
        },
      ),
      cancelToken: _cancelToken,
    )
        .then((response) {
      if (response.statusCode == 200) {
        response.data.stream.listen(
          (data) => controller.add(data),
          onError: (error) => controller.addError(error),
          onDone: () {
            _cancelToken = null;
            controller.close();
          },
        );
      } else {
        controller.addError(
          Exception(
              'Failed to fetch stream. Status code: ${response.statusCode}'),
        );
        _cancelToken = null;
        controller.close();
      }
    }).catchError((error) {
      controller.addError(error);
      _cancelToken = null;
      controller.close();
    });

    return controller.stream.map((data) => Uint8List.fromList(data));
  }

  @override
  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }
}
