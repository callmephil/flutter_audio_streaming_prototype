import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class TTSServiceMobile {
  final Dio _dio;
  CancelToken? _cancelToken;

  TTSServiceMobile(String apiKey)
      : _dio = Dio(
          BaseOptions(
            baseUrl: 'https://api.openai.com/v1/audio',
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
            },
          ),
        );

  void _createCancelToken() {
    _cancelToken = CancelToken();
  }

  Future<Stream<Uint8List>> tts(
    Map<String, dynamic> payload, {
    void Function(int, int)? onReceiveProgress,
  }) async {
    final data = jsonEncode(payload);

    try {
      _createCancelToken();
      final response = await _dio.post<ResponseBody>(
        '/speech',
        data: data,
        cancelToken: _cancelToken,
        options: Options(responseType: ResponseType.stream),
        onReceiveProgress: onReceiveProgress,
      );

      if (response.statusCode == 200) {
        return response.data?.stream ?? const Stream.empty();
      }

      throw Exception(
        'Failed to download TTS audio: ${response.statusCode ?? 'unknown'}',
      );
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('Request to TTS service was cancelled.');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error in tts: $e');
      return Future.error(e);
    }
  }

  void cancel() {
    _cancelToken?.cancel();
  }
}
