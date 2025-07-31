// lib/services/audio_route_service.dart
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum AudioInputDevice {
  builtInMic,
  headsetMic,
  bluetoothMic,
  externalMic,
  unknown;

  static AudioInputDevice fromString(String value) {
    switch (value.toLowerCase()) {
      case 'builtin':
      case 'phone':
        return AudioInputDevice.builtInMic;
      case 'headset':
      case 'wired':
        return AudioInputDevice.headsetMic;
      case 'bluetooth':
        return AudioInputDevice.bluetoothMic;
      case 'external':
        return AudioInputDevice.externalMic;
      default:
        return AudioInputDevice.unknown;
    }
  }

  @override
  String toString() {
    switch (this) {
      case AudioInputDevice.builtInMic:
        return 'builtin';
      case AudioInputDevice.headsetMic:
        return 'headset';
      case AudioInputDevice.bluetoothMic:
        return 'bluetooth';
      case AudioInputDevice.externalMic:
        return 'external';
      case AudioInputDevice.unknown:
        return 'unknown';
    }
  }
}

enum AudioOutputDevice {
  speaker,
  headphones,
  bluetoothHeadphones,
  externalSpeaker,
  unknown;

  static AudioOutputDevice fromString(String value) {
    switch (value.toLowerCase()) {
      case 'speaker':
        return AudioOutputDevice.speaker;
      case 'headphones':
      case 'wired':
        return AudioOutputDevice.headphones;
      case 'bluetooth':
        return AudioOutputDevice.bluetoothHeadphones;
      case 'external':
        return AudioOutputDevice.externalSpeaker;
      default:
        return AudioOutputDevice.unknown;
    }
  }
}

enum AudioRouteQuality {
  excellent,  // Headset mic + headphones
  good,       // External mic + headphones
  fair,       // Mixed setup
  poor,       // Built-in mic + headphones (some leakage)
  terrible;   // Built-in mic + speaker (maximum leakage)

  String get description {
    switch (this) {
      case AudioRouteQuality.excellent:
        return "Perfect setup! Headset microphone with headphones.";
      case AudioRouteQuality.good:
        return "Good setup! External microphone detected.";
      case AudioRouteQuality.fair:
        return "Fair setup. Audio quality may vary.";
      case AudioRouteQuality.poor:
        return "Poor setup. Phone mic with headphones may cause audio leakage.";
      case AudioRouteQuality.terrible:
        return "Poor setup. Speaker output will interfere with microphone.";
    }
  }

  Color get color {
    switch (this) {
      case AudioRouteQuality.excellent:
        return const Color(0xFF4CAF50); // Green
      case AudioRouteQuality.good:
        return const Color(0xFF8BC34A); // Light Green
      case AudioRouteQuality.fair:
        return const Color(0xFFFF9800); // Orange
      case AudioRouteQuality.poor:
        return const Color(0xFFFF5722); // Deep Orange
      case AudioRouteQuality.terrible:
        return const Color(0xFFF44336); // Red
    }
  }
}

class AudioRouteService {
  static const MethodChannel _channel = MethodChannel('audio_route');

  /// Check what audio input device is currently active
  static Future<AudioInputDevice> getCurrentInputDevice() async {
    try {
      final result = await _channel.invokeMethod('getCurrentInputDevice');
      return AudioInputDevice.fromString(result ?? 'builtin');
    } catch (e) {
      print('Error getting current input device: $e');
      return AudioInputDevice.builtInMic;
    }
  }

  /// Check what audio output device is currently active
  static Future<AudioOutputDevice> getCurrentOutputDevice() async {
    try {
      final result = await _channel.invokeMethod('getCurrentOutputDevice');
      return AudioOutputDevice.fromString(result ?? 'speaker');
    } catch (e) {
      print('Error getting current output device: $e');
      return AudioOutputDevice.speaker;
    }
  }

  /// Check if headset with microphone is connected
  static Future<bool> isHeadsetMicConnected() async {
    try {
      final result = await _channel.invokeMethod('isHeadsetMicConnected');
      return result == true;
    } catch (e) {
      print('Error checking headset mic: $e');
      return false;
    }
  }

  /// Check if any headset is connected (for output)
  static Future<bool> isHeadsetConnected() async {
    try {
      final result = await _channel.invokeMethod('isHeadsetConnected');
      return result == true;
    } catch (e) {
      print('Error checking headset: $e');
      return false;
    }
  }

  /// Get audio route quality assessment for singing apps
  static Future<AudioRouteQuality> getAudioQuality() async {
    try {
      final inputDevice = await getCurrentInputDevice();
      final outputDevice = await getCurrentOutputDevice();

      // Ideal: Headset mic + headset output
      if (inputDevice == AudioInputDevice.headsetMic &&
          outputDevice == AudioOutputDevice.headphones) {
        return AudioRouteQuality.excellent;
      }

      // Good: Any external mic + headset output
      if (inputDevice != AudioInputDevice.builtInMic &&
          outputDevice == AudioOutputDevice.headphones) {
        return AudioRouteQuality.good;
      }

      // Poor: Built-in mic + headset output (audio leakage likely)
      if (inputDevice == AudioInputDevice.builtInMic &&
          outputDevice == AudioOutputDevice.headphones) {
        return AudioRouteQuality.poor;
      }

      // Bad: Built-in mic + speaker (maximum audio leakage)
      if (inputDevice == AudioInputDevice.builtInMic &&
          outputDevice == AudioOutputDevice.speaker) {
        return AudioRouteQuality.terrible;
      }

      return AudioRouteQuality.fair;
    } catch (e) {
      print('Error getting audio quality: $e');
      return AudioRouteQuality.fair;
    }
  }
}