import 'dart:async';
import 'dart:typed_data';

import 'package:example/tts_service_web.dart';
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

  @override
  void dispose() {
    unawaited(SoLoud.instance.disposeAllSources());
    super.dispose();
  }

  Future<void> _fetchAndPlayAudio() async {
    final stream = TTSServiceWeb(openAIKey).tts(
      'https://api.openai.com/v1/audio',
      {
        'model': 'tts-1',
        'voice': 'alloy',
        'speed': 1,
        'input': '''1. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            2. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            3. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            4. Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            5. Lorem ipsum dolor sit amet, consectetur adipiscing elit.''',
        'response_format': 'pcm',
        'stream': true,
      },
    );

    final currentSound = SoLoud.instance.setBufferStream(
      maxBufferSize: 1024 * 1024 * 5, // 2 MB
      sampleRate: 24000,
      channels: Channels.mono,
      pcmFormat: BufferPcmType.s16le,
      onBuffering: (isBuffering, handle, time) async {
        debugPrint('buffering');
      },
    );

    int chunkNumber = 0;
    BytesBuilder data = BytesBuilder();

    stream.listen((chunk) async {
      data.add(chunk);

      try {
        SoLoud.instance.addAudioDataStream(
          currentSound,
          chunk,
          // Uint8List.fromList(decoded),
        );
        if (chunkNumber == 0) {
          await SoLoud.instance.play(currentSound);
        }
        chunkNumber++;
        print('chunk number: $chunkNumber');
        print('chunk length: ${chunk.length}');
      } on SoLoudPcmBufferFullCppException {
        debugPrint('pcm buffer full or stream already set '
            'to be ended');
      } catch (e) {
        debugPrint(e.toString());
      }
    }, onDone: () {
      // SoLoud.instance
      //     .loadMem('path', data.toBytes())
      //     .then((e) => SoLoud.instance.play(e));

      SoLoud.instance.setDataIsEnded(currentSound);
    });
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
