import 'dart:math' as math;

class PitchDetectionResult {
  final double frequency;
  final String note;
  final double confidence;
  final String swarNotation;

  PitchDetectionResult({
    required this.frequency,
    required this.note,
    required this.confidence,
    required this.swarNotation,
  });
}

class PitchDetectionService {
  // Indian Classical Music frequency mapping (Shadja = C4 = 261.63 Hz base)
  static const Map<String, double> noteFrequencies = {
    'Sa': 261.63,   // C4 - Middle Sa
    'Re': 293.66,   // D4
    'Ga': 329.63,   // E4
    'Ma': 349.23,   // F4
    'Pa': 392.00,   // G4
    'Dha': 440.00,  // A4
    'Ni': 493.88,   // B4
    'Sa\'': 523.25, // C5 - Higher octave Sa (Tar Shadja)
  };

  static const Map<String, String> noteToSwar = {
    'Sa': 'सा',
    'Re': 'रे',
    'Ga': 'ग',
    'Ma': 'म',
    'Pa': 'प',
    'Dha': 'ध',
    'Ni': 'नि',
    'Sa\'': 'सा\'', // Higher octave Sa with apostrophe
  };

  PitchDetectionResult detectPitch(List<double> audioSamples, int sampleRate) {
    try {
      // Ensure we have enough samples for analysis
      if (audioSamples.length < 1024) {
        return PitchDetectionResult(
          frequency: 0.0,
          note: '',
          confidence: 0.0,
          swarNotation: '',
        );
      }

      // Use YIN algorithm for pitch detection (more accurate than FFT for voice)
      final pitchResult = _yinPitchDetection(audioSamples, sampleRate);

      // Convert frequency to musical note
      final noteResult = _frequencyToNote(pitchResult.frequency);

      return PitchDetectionResult(
        frequency: pitchResult.frequency,
        note: noteResult['note'] ?? '',
        confidence: pitchResult.confidence * (noteResult['confidence'] ?? 0.0),
        swarNotation: noteResult['swar'] ?? '',
      );
    } catch (e) {
      return PitchDetectionResult(
        frequency: 0.0,
        note: '',
        confidence: 0.0,
        swarNotation: '',
      );
    }
  }

  // YIN algorithm implementation for accurate pitch detection
  YinResult _yinPitchDetection(List<double> buffer, int sampleRate) {
    const double threshold = 0.15;
    const int minPeriod = 20;  // Minimum period (for high frequencies)

    // Calculate the maximum period we want to check
    int maxPeriod = math.min(buffer.length ~/ 2, sampleRate ~/ 50); // 50 Hz minimum

    if (maxPeriod <= minPeriod) {
      return YinResult(frequency: 0.0, confidence: 0.0);
    }

    // Step 1: Calculate the difference function
    List<double> yinBuffer = List.filled(maxPeriod, 0.0);

    for (int tau = 0; tau < maxPeriod; tau++) {
      for (int i = 0; i < maxPeriod; i++) {
        double delta = buffer[i] - buffer[i + tau];
        yinBuffer[tau] += delta * delta;
      }
    }

    // Step 2: Calculate the cumulative mean normalized difference function
    yinBuffer[0] = 1.0;
    double runningSum = 0.0;

    for (int tau = 1; tau < maxPeriod; tau++) {
      runningSum += yinBuffer[tau];
      if (runningSum != 0) {
        yinBuffer[tau] *= tau / runningSum;
      } else {
        yinBuffer[tau] = 1.0;
      }
    }

    // Step 3: Search for the best period
    int bestPeriod = -1;
    double minValue = double.infinity;

    for (int tau = minPeriod; tau < maxPeriod; tau++) {
      if (yinBuffer[tau] < threshold) {
        // Find the minimum in this dip
        while (tau + 1 < maxPeriod && yinBuffer[tau + 1] < yinBuffer[tau]) {
          tau++;
        }
        bestPeriod = tau;
        minValue = yinBuffer[tau];
        break;
      }
    }

    // If no period found below threshold, find global minimum
    if (bestPeriod == -1) {
      for (int tau = minPeriod; tau < maxPeriod; tau++) {
        if (yinBuffer[tau] < minValue) {
          minValue = yinBuffer[tau];
          bestPeriod = tau;
        }
      }
    }

    if (bestPeriod == -1 || bestPeriod == 0) {
      return YinResult(frequency: 0.0, confidence: 0.0);
    }

    // Step 4: Parabolic interpolation for better accuracy
    double betterPeriod = _parabolicInterpolation(yinBuffer, bestPeriod);

    // Calculate frequency and confidence
    double frequency = sampleRate / betterPeriod;
    double confidence = 1.0 - minValue;

    // Filter out unrealistic frequencies for human voice
    if (frequency < 80 || frequency > 1000) {
      return YinResult(frequency: 0.0, confidence: 0.0);
    }

    // Boost confidence for frequencies in typical singing range
    if (frequency >= 130 && frequency <= 520) { // Typical human singing range
      confidence = math.min(1.0, confidence * 1.2);
    }

    return YinResult(frequency: frequency, confidence: confidence);
  }

  // Parabolic interpolation to get sub-sample accuracy
  double _parabolicInterpolation(List<double> yinBuffer, int tauEstimate) {
    if (tauEstimate <= 0 || tauEstimate >= yinBuffer.length - 1) {
      return tauEstimate.toDouble();
    }

    double s0 = yinBuffer[tauEstimate - 1];
    double s1 = yinBuffer[tauEstimate];
    double s2 = yinBuffer[tauEstimate + 1];

    double a = (s0 - 2 * s1 + s2) / 2;
    if (a.abs() < 1e-10) {
      return tauEstimate.toDouble();
    }

    double b = (s2 - s0) / 2;
    double correction = -b / (2 * a);

    return tauEstimate + correction;
  }

  Map<String, dynamic> _frequencyToNote(double frequency) {
    if (frequency <= 0) {
      return {'note': '', 'confidence': 0.0, 'swar': ''};
    }

    String closestNote = '';
    double closestFreq = 0.0;
    double minDifference = double.infinity;

    // Check against all octaves (2 octaves below to 2 above)
    for (int octave = -2; octave <= 2; octave++) {
      noteFrequencies.forEach((note, baseFreq) {
        double octaveFreq = baseFreq * math.pow(2, octave);
        double difference = (frequency - octaveFreq).abs();

        if (difference < minDifference) {
          minDifference = difference;
          closestNote = note;
          closestFreq = octaveFreq;
        }
      });
    }

    // Calculate confidence based on frequency accuracy
    double percentError = (minDifference / closestFreq) * 100;
    double confidence = math.max(0.0, 1.0 - (percentError / 25)); // 25% tolerance

    // Only return result if confidence is reasonable
    if (confidence < 0.2) {
      return {'note': '', 'confidence': 0.0, 'swar': ''};
    }

    return {
      'note': closestNote,
      'confidence': confidence,
      'swar': noteToSwar[closestNote] ?? '',
    };
  }
}

// Helper class for YIN algorithm results
class YinResult {
  final double frequency;
  final double confidence;

  YinResult({required this.frequency, required this.confidence});
}