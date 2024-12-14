import 'dart:async';

import 'package:example/buffer_widget.dart';
import 'package:example/strings.dart';
import 'package:example/tts_service.dart';
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
    final stream = TTSService(openAIKey).tts(
      'https://api.openai.com/v1/audio/speech',
      {
        'model': 'tts-1',
        'voice': 'alloy',
        'speed': 1,
        'input': _textController.text,
        'response_format': 'pcm',
        'stream': true,
      },
      chunkSize: 1024 * 32, // 32kb before speech
    );

    currentSound = SoLoud.instance.setBufferStream(
      maxBufferSize: 1024 * 1024 * 50, // 50 MB
      sampleRate: 24000,
      channels: Channels.mono,
      pcmFormat: BufferPcmType.s16le,
      bufferingTimeNeeds: 0.5,
      // onBuffering: (isBuffering, handle, time) async {
      //   // debugPrint('isBuffering ${[isBuffering, handle, time]}');
      // },
    );

    var chunkNumber = 0;

    stream.listen(
      (chunk) async {
        try {
          SoLoud.instance.addAudioDataStream(
            currentSound!,
            chunk,
          );
          if (chunkNumber == 0) {
            await SoLoud.instance.play(currentSound!);
            // To display the BufferWidget
            if (context.mounted) {
              setState(() {});
            }
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
      onError: (e) {
        debugPrint('Error: $e');
      },
    );
  }

  final TextEditingController _textController =
      TextEditingController(text: longString);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Stream Example'),
      ),
      body: Center(
        child: Column(
          children: [
            Expanded(
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width * 0.8,
                child: TextField(
                  controller: _textController,
                  decoration: const InputDecoration(
                    hintText: 'Enter text to convert to audio',
                  ),
                  minLines: 1,
                  maxLines: null,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _fetchAndPlayAudio,
                  child: const Text('Play Audio'),
                ),
                const SizedBox(width: 12),
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
            BufferBar(sound: currentSound),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
