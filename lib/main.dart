import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:example/audio_player_controller.dart';
import 'package:example/tts_service_web.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: AudioStreamScreen(),
    );
  }
}

class AudioStreamScreen extends StatefulWidget {
  const AudioStreamScreen({super.key});

  @override
  State<AudioStreamScreen> createState() => _AudioStreamScreenState();
}

class _AudioStreamScreenState extends State<AudioStreamScreen> {
  // TODO: add your open ai key if you want to test
  final openAIKey = 'YOUR_OPENAI_API_KEY';

  final Queue<Uint8List> _bufferQueue = Queue();
  final BytesBuilder _currentBuffer = BytesBuilder();
  bool _isPlaying = false;
  final int _bufferSize = 64 * 1024; // Adjusted buffer size
  AudioPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = AudioPlayerController(onError: (e, s) {
      debugPrint('Error: $e');
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _fetchAndPlayAudio() async {
    final stream = TTSServiceWeb(openAIKey).tts(
      'https://api.openai.com/v1/audio/speech',
      {
        'model': 'tts-1',
        'voice': 'alloy',
        'speed': 1,
        'input':
            '''Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.''',
        'response_format': 'opus',
        'stream': true,
      },
    );

    try {
      await for (final chunk in stream) {
        _addToBuffer(chunk);
        if (_currentBuffer.length >= _bufferSize) {
          debugPrint(
              'New Buffer: ${_currentBuffer.toBytes().lengthInBytes} / $_bufferSize');
          _flushBufferToQueue();
        }
        debugPrint('Last chunk: ${chunk.lengthInBytes / 1024} KB');

        _playNextInQueue();
      }
      _flushBufferToQueue(finalFlush: true);
    } catch (e) {
      debugPrint('Error fetching audio: $e');
    }
  }

  void _addToBuffer(Uint8List chunk) {
    _currentBuffer.add(chunk);
  }

  void _flushBufferToQueue({bool finalFlush = false}) {
    if (_currentBuffer.isNotEmpty) {
      _bufferQueue.add(_currentBuffer.toBytes());
      _currentBuffer.clear();
    }
    if (finalFlush) {
      _playNextInQueue();
    }
  }

  Future<void> _playNextInQueue() async {
    if (_isPlaying || _bufferQueue.isEmpty) return;

    final nextChunk = _bufferQueue.removeFirst();
    _isPlaying = true;

    try {
      debugPrint('Playing chunk: ${nextChunk.lengthInBytes / 1024} KB');
      await _controller?.play(nextChunk);
    } catch (e) {
      debugPrint('Error playing chunk: $e');
    } finally {
      _isPlaying = false;
      if (_bufferQueue.isNotEmpty) {
        _playNextInQueue();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Stream Example'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _fetchAndPlayAudio,
          child: const Text('Play Audio'),
        ),
      ),
    );
  }
}
