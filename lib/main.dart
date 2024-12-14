import 'dart:async';

import 'package:example/tts_service_all.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize the player.
  await SoLoud.instance.init();

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
  final openAIKey = 'YOUR API KEY';
  AudioSource? currentSound;

  @override
  void dispose() {
    unawaited(SoLoud.instance.disposeAllSources());
    super.dispose();
  }

  Future<void> _fetchAndPlayAudio() async {
    final stream = TTSServiceAll(openAIKey).tts(
      'https://api.openai.com/v1/audio/speech',
      {
        'model': 'tts-1',
        'voice': 'alloy',
        'speed': 1,
        'input': 'Today is a wonderful day to build something people love!',
        'response_format': 'pcm',
        'stream': true,
      },
    );

    currentSound = SoLoud.instance.setBufferStream(
      maxBufferSize: 1024 * 1024 * 5, // 2 MB
      sampleRate: 24000,
      channels: Channels.mono,
      pcmFormat: BufferPcmType.s16le,
      bufferingTimeNeeds: 0.5,
      onBuffering: (isBuffering, handle, time) async {
        debugPrint('buffering');
      },
    );

    var chunkNumber = 0;

    stream.listen(
      (chunk) async {
        debugPrint('LISTEN $chunkNumber********** ${chunk.length}');
        try {
          SoLoud.instance.addAudioDataStream(
            currentSound!,
            chunk,
          );
          if (chunkNumber == 0) {
            await SoLoud.instance.play(currentSound!);
          }
          chunkNumber++;
        } on SoLoudPcmBufferFullCppException {
          debugPrint('pcm buffer full or stream already set '
              'to be ended');
        } catch (e) {
          debugPrint(e.toString());
        }
      },
      onDone: () {
        SoLoud.instance.setDataIsEnded(currentSound!);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Stream Example'),
      ),
      body: Center(
        child: Column(
          spacing: 10,
          children: [
            ElevatedButton(
              onPressed: _fetchAndPlayAudio,
              child: const Text('Play Audio'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentSound != null) {
                  await SoLoud.instance.play(currentSound!);
                }
              },
              child: const Text('Play Last Audio'),
            ),
          ],
        ),
      ),
    );
  }
}
