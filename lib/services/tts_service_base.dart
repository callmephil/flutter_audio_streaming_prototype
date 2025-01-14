import 'dart:async';
import 'dart:typed_data';

abstract class TTSServiceBase {
  final String apiKey;

  TTSServiceBase(this.apiKey);

  /// Converts text to speech stream
  Stream<Uint8List> tts(String url, Map<String, dynamic> payload);

  /// Cancels ongoing TTS request
  void cancel();
}
