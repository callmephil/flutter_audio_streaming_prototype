import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioPlayerController {
  AudioPlayerController({required this.onError});

  final AudioPlayer _audioPlayer = AudioPlayer();
  final void Function(Object e, StackTrace stackTrace) onError;

  Future<void> play(Uint8List bytes) async {
    try {
      debugPrint('Playing audio... ${_audioPlayer.state}');
      if (_audioPlayer.state == PlayerState.playing) {
        try {
          await _audioPlayer.stop();
          debugPrint('Audio stopped successfully.');
        } catch (e, s) {
          debugPrint('Error stopping audio: $e');
          onError(e, s);
        }
      }

      try {
        await _audioPlayer.setSourceBytes(bytes, mimeType: 'audio/mpeg');
        debugPrint('Audio source set successfully.');
      } catch (e, s) {
        debugPrint('Error setting audio source: $e');
        onError(e, s);
      }

      try {
        await _audioPlayer.resume();
        debugPrint('Audio resumed successfully.');
      } catch (e, s) {
        debugPrint('Error resuming audio: $e');
        onError(e, s);
      }

      try {
        // stop the audio when it completes
        await for (final _ in _audioPlayer.onPlayerComplete) {
          // ignore: avoid-unconditional-break
          break;
        }

        debugPrint('Audio playback completed.');
      } catch (e, s) {
        debugPrint('Error waiting for audio completion: $e');
        onError(e, s);
      }
    } catch (e, s) {
      debugPrint('Unexpected error: $e');
      onError(e, s);
    }
  }

  /// Disposes of the resources used by the controller.
  void dispose() {
    try {
      _audioPlayer.dispose();
    } catch (e, s) {
      debugPrint('Error disposing AudioController: $e');
      onError(e, s);
    }
  }
}
