import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

class MicrophoneService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  Timer? _volumeTimer;

  bool _isRecording = false;
  double _currentVolume = 0.0;
  List<double> _audioSamples = [];

  Function(double)? _onVolumeChanged;
  Function(String)? _onError;
  Function(List<double>)? _onAudioData;

  bool get isRecording => _isRecording;
  double get currentVolume => _currentVolume;
  List<double> get latestAudioSamples => List.from(_audioSamples);

  Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  Future<void> startListening({
    Function(double)? onVolumeChanged,
    Function(String)? onError,
    Function(List<double>)? onAudioData,
  }) async {
    try {
      _onVolumeChanged = onVolumeChanged;
      _onError = onError;
      _onAudioData = onAudioData;

      // Check permission first
      if (!await hasPermission()) {
        throw Exception('Microphone permission not granted');
      }

      // Start recording stream with optimal settings for pitch detection
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 44100, // High sample rate for better frequency resolution
          numChannels: 1,
        ),
      );

      _isRecording = true;
      _audioSamples.clear();

      // Listen to audio stream for analysis
      _audioStreamSubscription = stream.listen(
            (data) {
          _processAudioData(data);
        },
        onError: (error) {
          _onError?.call('Audio stream error: $error');
          stopListening();
        },
      );

      // Start monitoring timer
      _startMonitoring();

    } catch (e) {
      _onError?.call('Failed to start recording: $e');
      _isRecording = false;
    }
  }

  void _processAudioData(Uint8List audioData) {
    if (audioData.isEmpty) return;

    // Calculate volume (existing functionality)
    _calculateVolume(audioData);

    // Convert raw audio data to samples for pitch detection
    _convertToAudioSamples(audioData);
  }

  void _calculateVolume(Uint8List audioData) {
    // Convert raw audio data to volume level
    double sum = 0;

    // Process audio as 16-bit samples
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Combine two bytes into 16-bit sample
      int sample = (audioData[i + 1] << 8) | audioData[i];

      // Convert to signed 16-bit
      if (sample > 32767) sample -= 65536;

      // Add to sum for RMS calculation
      sum += sample * sample;
    }

    // Calculate RMS and normalize to 0-1 range
    double rms = 0;
    if (audioData.length > 0) {
      rms = (sum / (audioData.length / 2)).abs();
      rms = (rms / (32767 * 32767)); // Normalize
      rms = rms.clamp(0.0, 1.0);
    }

    _currentVolume = rms;
  }

  void _convertToAudioSamples(Uint8List audioData) {
    // Convert 16-bit PCM to double samples for pitch detection
    List<double> newSamples = [];

    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = (audioData[i + 1] << 8) | audioData[i];

      // Convert to signed 16-bit
      if (sample > 32767) sample -= 65536;

      // Normalize to -1.0 to 1.0 range
      double normalizedSample = sample / 32767.0;
      newSamples.add(normalizedSample);
    }

    // Add new samples to buffer
    _audioSamples.addAll(newSamples);

    // Keep only the last 4096 samples (about 93ms at 44.1kHz)
    // This provides enough data for pitch detection while staying responsive
    const int maxSamples = 4096;
    if (_audioSamples.length > maxSamples) {
      _audioSamples = _audioSamples.sublist(_audioSamples.length - maxSamples);
    }

    // Provide audio data to callback
    if (_audioSamples.length >= 2048) { // Minimum samples for reliable detection
      _onAudioData?.call(List.from(_audioSamples));
    }
  }

  void _startMonitoring() {
    _volumeTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      _onVolumeChanged?.call(_currentVolume);
    });
  }

  Future<void> stopListening() async {
    try {
      _isRecording = false;

      // Cancel audio stream subscription
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;

      // Stop monitoring
      _volumeTimer?.cancel();
      _volumeTimer = null;

      // Stop recording
      await _recorder.stop();

      // Reset values
      _currentVolume = 0.0;
      _audioSamples.clear();

      _onVolumeChanged?.call(0.0);
      _onAudioData?.call([]);

    } catch (e) {
      _onError?.call('Error stopping recording: $e');
    }
  }

  void dispose() {
    stopListening();
    _recorder.dispose();
  }
}