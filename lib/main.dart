import 'dart:async';

import 'package:example/extensions/stream_chunking_extension.dart';
import 'package:example/services/tts_service.dart';
import 'package:example/strings.dart';
import 'package:flutter/foundation.dart';
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
  static const openAIKey = '';
  AudioSource? currentSound;
  // TODO: Build is not working yet on web but later we can turn that off to swap between pcm and opus for testing.
  bool get usePCM => kIsWeb;

  @override
  void dispose() {
    unawaited(SoLoud.instance.disposeAllSources());
    super.dispose();
  }

  final Stopwatch _stopwatch = Stopwatch();

  bool _isPlaying = false;

  final _ttsService = TTSService(openAIKey);
  StreamSubscription<Uint8List>? _streamSubscription;

  void _cancel() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
    _ttsService.cancel();
    SoLoud.instance.disposeSource(currentSound!);

    setState(() {
      _isPlaying = false;
    });
  }

  Future<void> _fetchAndPlayAudio() async {
    if (_isPlaying) {
      _cancel();
      return;
    }
    _stopwatch.start();

    Stream<Uint8List> stream = _ttsService.tts(
      'https://api.openai.com/v1/audio/speech',
      {
        'model': 'tts-1',
        'voice': 'alloy',
        'speed': 1,
        'input': _textController.text,
        'response_format': usePCM ? 'pcm' : 'opus',
        'stream': true,
      },
    );

    if (usePCM) {
      stream = stream.chunked(1024 * 2);
    }

    currentSound = SoLoud.instance.setBufferStream(
      maxBufferSize: 1024 * 1024 * 50, // 50 MB
      sampleRate: 24000,
      channels: Channels.mono,
      format: usePCM ? BufferType.s16le : BufferType.opus,
      bufferingTimeNeeds: 0.5,
      // onBuffering: (isBuffering, handle, time) async {
      //   // // debugPrint('isBuffering ${[isBuffering, handle, time]}');
      // },
    );
    debugPrint('elapsed time: ${_stopwatch.elapsed.inSeconds}');

    _stopwatch.reset();

    var chunkNumber = 0;

    _isPlaying = true;

    _streamSubscription = stream.listen(
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
          debugPrint('pcm buffer full or stream already set to be ended');
        } catch (e) {
          debugPrint(e.toString());
        }
      },
      onDone: () {
        SoLoud.instance.setDataIsEnded(currentSound!);
        _isPlaying = false;
      },
      onError: (e) {
        _isPlaying = false;
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
                  child: _isPlaying
                      ? const Text('Cancel...')
                      : const Text('Play Audio'),
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
            // TODO: this is broken, will fix later
            // BufferBar(sound: currentSound),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
