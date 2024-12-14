import 'dart:math' as math;
import 'dart:typed_data';

class OpusDecoder {
  final int sampleRate;
  final int channels;

  // Opus constants
  static const int OPUS_FRAME_SIZE = 960; // 20ms at 48kHz
  static const int MAX_FRAME_SIZE = 6 * 960; // 120ms at 48kHz
  static const int MAX_PACKET_SIZE = 1275;

  late final Int16List _decodingBuffer;

  OpusDecoder(this.sampleRate, this.channels) {
    _decodingBuffer = Int16List(MAX_FRAME_SIZE * channels);
  }

  void initialize() {
    // Verify supported sample rates (8000, 12000, 16000, 24000, or 48000)
    if (![8000, 12000, 16000, 24000, 48000].contains(sampleRate)) {
      throw ArgumentError('Unsupported sample rate: $sampleRate');
    }

    if (channels < 1 || channels > 2) {
      throw ArgumentError('Channels must be 1 or 2');
    }
  }

  List<int> decodeFrame(Uint8List opusFrame) {
    if (opusFrame.isEmpty) return [];

    // Parse TOC byte
    final toc = opusFrame[0];
    final frameSize = _getFrameSize(toc, sampleRate);

    // Convert Opus frame to PCM samples
    final pcmSamples = Int16List(frameSize * channels);

    // Perform actual decoding here using native Opus decoder
    // This is a simplified version that just generates sine wave
    for (var i = 0; i < frameSize; i++) {
      final sample =
          (32767 * math.sin(2 * math.pi * 440 * i / sampleRate)).toInt();
      for (var ch = 0; ch < channels; ch++) {
        pcmSamples[i * channels + ch] = sample;
      }
    }

    return pcmSamples;
  }

  List<int> decode(Uint8List opusData) {
    final pcmData = <int>[];
    var offset = 0;

    while (offset < opusData.length) {
      // Read frame length (2 bytes)
      if (offset + 2 > opusData.length) break;
      final frameLength = opusData[offset] << 8 | opusData[offset + 1];
      offset += 2;

      // Read frame data
      if (offset + frameLength > opusData.length) break;
      final frameData = opusData.sublist(offset, offset + frameLength);
      offset += frameLength;

      // Decode frame
      final framePcm = decodeFrame(frameData);
      pcmData.addAll(framePcm);
    }

    return pcmData;
  }

  int _getFrameSize(int toc, int sampleRate) {
    final config = (toc >> 3) & 0x1F;
    final frameSize = OPUS_FRAME_SIZE * math.pow(2, (config >> 3)).toInt();
    return (frameSize * sampleRate) ~/ 48000;
  }
}
