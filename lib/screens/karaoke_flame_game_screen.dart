import 'dart:async';
import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/lesson_model.dart';
import '../services/microphone_service.dart';
import '../services/pitch_detection_service.dart';
import 'session_summary_screen.dart';

// Data class for Flame game usage
class PitchPoint {
  final double frequency;
  final int timestamp;
  final double confidence;
  PitchPoint({required this.frequency, required this.timestamp, required this.confidence});
}

// FLAME GAME CLASS---------------------------------------------------------
class KaraokeFlamePracticeGame extends FlameGame {
  // Set externally -- atomic values for smooth UI
  late List<PracticeNote> practiceNotes;
  late List<PitchPoint> userPitchPoints;
  late PracticeNote? activeNote;
  double playheadX = 160.0;
  int visibleDurationMs = 16000; // set externally
  double audioSmoothMs = 0; // set externally (current ms of audio, smoothed!)
  double Function(double, double) frequencyToY;

  KaraokeFlamePracticeGame({
    required this.practiceNotes,
    required this.userPitchPoints,
    required this.activeNote,
    required this.visibleDurationMs,
    required this.frequencyToY,
  });

  @override
  Color backgroundColor() => const Color(0xFF2A2E4C);

  @override
  void render(Canvas canvas) {
    final sw = size.x;
    final sh = size.y;

    // --- Draw grid lines
    final double graphTop = sh * 0.1;
    final double graphBottom = sh * 0.9;
    final double graphHeight = graphBottom - graphTop;
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0;
    for (int i = 0; i <= 8; i++) {
      final y = graphTop + (i / 8) * graphHeight;
      canvas.drawLine(Offset(0, y), Offset(sw, y), gridPaint);
    }

    // --- Practice Notes (with color and animation)
    final pixelsPerMs = sw / visibleDurationMs;
    for (final note in practiceNotes) {
      final startX = playheadX + (note.startTime - audioSmoothMs) * pixelsPerMs;
      final endX = playheadX + (note.endTime - audioSmoothMs) * pixelsPerMs;
      if (startX > sw || endX < 0) continue;
      final y = frequencyToY(note.frequency, sh);
      final noteWidth = endX - startX;
      final isActive = activeNote == note;
      final isPassed = note.endTime < audioSmoothMs;
      final color = isActive
          ? Colors.orangeAccent
          : isPassed
          ? Colors.grey.withOpacity(0.6)
          : Colors.amber.withOpacity(0.8);
      final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX, y - 5, noteWidth, 10), const Radius.circular(5));
      final notePaint = Paint()..color = color;
      canvas.drawRRect(rect, notePaint);
    }

    // --- User Pitch Line (shadow + main)
    if (userPitchPoints.length > 1) {
      final minTimestamp = (audioSmoothMs - visibleDurationMs ~/ 2.0).toInt();
      final maxTimestamp = (audioSmoothMs + visibleDurationMs ~/ 2.0).toInt();
      final path = Path();
      bool moved = false;
      for (int i = 0; i < userPitchPoints.length - 1; i++) {
        final p1 = userPitchPoints[i];
        final p2 = userPitchPoints[i + 1];
        if (p2.timestamp < minTimestamp) continue;
        if (p1.timestamp > maxTimestamp) break;
        final x1 = playheadX - (audioSmoothMs - p1.timestamp) * pixelsPerMs;
        final y1 = frequencyToY(p1.frequency, sh);
        final x2 = playheadX - (audioSmoothMs - p2.timestamp) * pixelsPerMs;
        final y2 = frequencyToY(p2.frequency, sh);
        if (!moved) {
          path.moveTo(x1, y1);
          moved = true;
        }
        path.lineTo(x2, y2);
      }
      final shadowPaint = Paint()
        ..color = Colors.cyanAccent.withOpacity(0.22)
        ..strokeWidth = 12
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
      canvas.drawPath(path, shadowPaint);

      final userPaint = Paint()
        ..color = Colors.cyanAccent
        ..strokeWidth = 3.5
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, userPaint);
    }

    // --- Playhead
    final playheadPaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2;
    canvas.drawLine(
        Offset(playheadX, graphTop), Offset(playheadX, graphBottom), playheadPaint);
  }
}

// KAROAKE PRACTICE SCREEN ===============================================
class KaraokePracticeScreen extends StatefulWidget {
  final Lesson lesson;

  const KaraokePracticeScreen({
    Key? key,
    required this.lesson,
  }) : super(key: key);

  @override
  _KaraokePracticeScreenState createState() => _KaraokePracticeScreenState();
}

class _KaraokePracticeScreenState extends State<KaraokePracticeScreen>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late MicrophoneService _microphoneService;
  late PitchDetectionService _pitchDetectionService;

  late AnimationController _animationController;

  // Audio state
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _duration = Duration.zero;

  // Microphone variables
  bool _isRecording = false;
  bool _microphonePermissionGranted = false;
  double _currentVolume = 0.0;
  String _microphoneStatus = 'Ready';

  // Pitch detection variables
  double _detectedFrequency = 0.0;

  // Practice tracking variables
  DateTime? _practiceStartTime;
  DateTime? _sessionStartTime;
  int _sessionPracticeMinutes = 0;
  Timer? _practiceTimer;
  bool _isActivelyPracticing = false;

  // Session summary data
  List<double> _pitchAccuracyHistory = [];
  double _totalAccuracy = 0.0;
  int _accuracyCount = 0;
  int _totalNotesAttempted = 0;
  int _correctNotes = 0;

  // Practice notes for the karaoke view
  late List<PracticeNote> _practiceNotes;
  PracticeNote? _currentActiveNote;

  // Flame game notes
  static const double _flamePlayheadX = 160.0;
  static const int _flameVisibleDurationMs = 20000;
  List<PitchPoint> _userPitchPoints = [];
  static const int MAX_PITCH_POINTS = 400;
  double _audioSmoothMs = 0.0;

  bool _isSetupComplete = false;
  double _screenWidth = 0;
  double _screenHeight = 0;

  double? _lastPitchSmoothed;
  KaraokeFlamePracticeGame? _flameGame;

  // Add these new variables for pitch snapping
  static const double PITCH_TOLERANCE_CENTS = 50.0; // ±50 cents tolerance
  static const double SNAP_SMOOTHING_FACTOR = 0.7; // How strong the snapping effect is

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight,
    ]);
    _audioPlayer = AudioPlayer();
    _microphoneService = MicrophoneService();
    _pitchDetectionService = PitchDetectionService();

    // AnimationController -- dummy duration, will set after audio loads.
    _animationController = AnimationController(
      duration: Duration.zero,
      vsync: this,
    );

    _practiceNotes = widget.lesson.practiceNotes;
    _sessionStartTime = DateTime.now();

    _flameGame = KaraokeFlamePracticeGame(
      practiceNotes: _practiceNotes,
      userPitchPoints: List.of(_userPitchPoints),
      activeNote: _currentActiveNote,
      visibleDurationMs: _flameVisibleDurationMs,
      frequencyToY: _frequencyToY,
    );

    _startSequentialInitialization();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    _stopPracticeTracking();
    _practiceTimer?.cancel();
    _animationController.dispose();
    _audioPlayer.dispose();
    _microphoneService.dispose();
    super.dispose();
  }

  Future<void> _startSequentialInitialization() async {
    try {
      await _initializeAudio();
      await _requestAndWaitForPermission();
      await _checkAudioSetupAndWait();
      await _checkAndResetDailyProgress();

      if (mounted) setState(() {
        _isSetupComplete = true;
      });

      _audioPlayer.play();
    } catch (e) {
      print('Initialization error: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize: $e';
        });
      }
    }
  }

  Future<void> _initializeAudio() async {
    try {
      final audioUrl = widget.lesson.practiceUrl.isNotEmpty
          ? widget.lesson.practiceUrl
          : widget.lesson.audioUrl;
      if (audioUrl.isEmpty) {
        throw Exception('No practice audio available for this lesson');
      }

      final duration = await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(audioUrl)),
      );

      if (duration != null && mounted) {
        setState(() {
          _duration = duration;
        });
        _animationController.duration = duration;
      }

      _audioPlayer.positionStream.listen((position) {
        // for smoothness: update value, game gets updated below
        if (mounted && _duration.inMilliseconds > 0) {
          final v = position.inMilliseconds / _duration.inMilliseconds;
          _animationController.value = v;
          _audioSmoothMs = _duration.inMilliseconds * v;
          // also update active note:
          _updateCurrentActiveNote(position);
          // (no setState: below triggers)
        }
        _updateFlameGame();
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;

        if (state.playing) {
          _animationController.forward();
          if (!_isRecording && _microphonePermissionGranted) {
            _startMicrophoneListening();
            _startPracticeTracking();
          }
        } else {
          _animationController.stop();
          if (_isRecording) {
            _stopPracticeTracking();
            _stopMicrophoneListening();
          }
        }

        if (state.processingState == ProcessingState.completed) {
          _finishSession();
        }

        setState(() {
          _isLoading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });
      });
    } catch (e) {
      throw Exception('Failed to load practice audio: $e');
    }
  }

  Future<void> _requestAndWaitForPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      if (mounted) setState(() {
        _microphonePermissionGranted = true;
      });
      return;
    }
    final requestedStatus = await Permission.microphone.request();
    if (mounted)
      setState(() {
        _microphonePermissionGranted = requestedStatus.isGranted;
      });
  }

  Future<void> _checkAudioSetupAndWait() async {}
  Future<void> _checkAndResetDailyProgress() async {}

  void _startPracticeTracking() {
    if (!_isActivelyPracticing) {
      _isActivelyPracticing = true;
      _practiceStartTime = DateTime.now();
      _practiceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updatePracticeTime();
      });
    }
  }

  void _stopPracticeTracking() {
    if (_isActivelyPracticing) {
      _updatePracticeTime();
      _practiceTimer?.cancel();
      _isActivelyPracticing = false;
    }
  }

  void _updatePracticeTime() {
    if (_practiceStartTime != null) {
      final practiceSeconds =
          DateTime.now().difference(_practiceStartTime!).inSeconds;
      final practiceMinutes = (practiceSeconds / 60).floor();
      if (practiceMinutes > 0) {
        if (mounted) setState(() {
          _sessionPracticeMinutes += practiceMinutes;
        });
        _practiceStartTime = DateTime.now();
      }
    }
  }

  void _recordPitchAccuracy(double accuracy) {
    _pitchAccuracyHistory.add(accuracy);
    _totalAccuracy += accuracy;
    _accuracyCount++;
    if (_currentActiveNote != null) {
      _totalNotesAttempted++;
      if (accuracy > 0.7) _correctNotes++;
    }
  }

  double get _averageAccuracy =>
      _accuracyCount > 0 ? _totalAccuracy / _accuracyCount : 0.0;

  Future<void> _finishSession() async {
    _stopPracticeTracking();
    if (_sessionStartTime != null) {
      final totalSessionMinutes =
          DateTime.now().difference(_sessionStartTime!).inMinutes;
      _sessionPracticeMinutes =
          math.max(_sessionPracticeMinutes, totalSessionMinutes);
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => SessionSummaryScreen(
          practiceMinutes: _sessionPracticeMinutes,
          lessonTitle: widget.lesson.title,
          averageAccuracy: _averageAccuracy * 100,
          totalNotesAttempted: math.max(_totalNotesAttempted, 1),
          correctNotes: _correctNotes,
          pitchAccuracyHistory: _pitchAccuracyHistory,
        ),
      ),
    );
  }

  void _updateCurrentActiveNote(Duration position) {
    final positionMs = position.inMilliseconds;
    PracticeNote? activeNote;
    for (final note in _practiceNotes) {
      if (positionMs >= note.startTime && positionMs <= note.endTime) {
        activeNote = note;
        break;
      }
    }
    if (_currentActiveNote != activeNote) {
      setState(() {
        _currentActiveNote = activeNote;
      });
    }
  }

  Future<void> _startMicrophoneListening() async {
    if (!_microphonePermissionGranted) return;
    try {
      await _microphoneService.startListening(
        onVolumeChanged: (volume) {
          if (mounted) setState(() => _currentVolume = volume);
        },
        onAudioData: _processAudioForPitchDetection,
        onError: (error) {
          if (mounted) setState(() => _microphoneStatus = 'Error: $error');
        },
      );
      if (mounted) setState(() {
        _isRecording = true;
      });
    } catch (e) {
      if (mounted) setState(() => _microphoneStatus = 'Failed to start: $e');
    }
  }

  // FLAME INTEGRATION with pitch snapping: --------
  void _processAudioForPitchDetection(List<double> audioSamples) {
    if (_audioPlayer.playing == false) return;
    if (_currentVolume < 0.01 || audioSamples.length < 2048) return;

    final result = _pitchDetectionService.detectPitch(
      audioSamples.sublist(audioSamples.length - 2048),
      44100,
    );
    final currentAudioPosition = _audioPlayer.position;
    final currentMs = currentAudioPosition.inMilliseconds;

    // Get the detected frequency
    double detectedFreq = result.frequency;

    // Apply pitch snapping if there's an active note
    double finalFreq = detectedFreq;
    double accuracy = 0.0;

    if (_currentActiveNote != null && result.confidence > 0.6) {
      final expectedFreq = _currentActiveNote!.frequency;
      final pitchDifference = _calculateCentsDifference(detectedFreq, expectedFreq);

      // Check if the user's pitch is within tolerance
      if (pitchDifference.abs() <= PITCH_TOLERANCE_CENTS) {
        // Calculate accuracy based on how close the pitch is
        accuracy = 1.0 - (pitchDifference.abs() / PITCH_TOLERANCE_CENTS);

        // Snap to the expected frequency with smoothing
        finalFreq = _applyPitchSnapping(detectedFreq, expectedFreq, accuracy);

        // Record this as a successful pitch match
        _recordPitchAccuracy(accuracy);
      } else {
        // Pitch is outside tolerance, use original frequency
        finalFreq = detectedFreq;
        accuracy = 0.0;
      }
    }

    // Apply temporal smoothing
    const alpha = 0.37;
    if (_lastPitchSmoothed != null) {
      finalFreq = _lastPitchSmoothed! * (1 - alpha) + finalFreq * alpha;
    }
    _lastPitchSmoothed = finalFreq;

    // Add the pitch point with the snapped frequency
    _userPitchPoints.add(PitchPoint(
      frequency: finalFreq,
      timestamp: currentMs,
      confidence: result.confidence,
    ));

    if (_userPitchPoints.length > MAX_PITCH_POINTS) {
      _userPitchPoints.removeAt(0);
    }

    // Update flame game
    _updateFlameGame();
    _detectedFrequency = finalFreq;
  }

  // Helper method to calculate the difference in cents between two frequencies
  double _calculateCentsDifference(double freq1, double freq2) {
    if (freq1 <= 0 || freq2 <= 0) return double.infinity;
    return 1200 * (math.log(freq1 / freq2) / math.ln2);
  }

  // Helper method to apply pitch snapping with smoothing
  double _applyPitchSnapping(double detectedFreq, double expectedFreq, double accuracy) {
    // The closer the accuracy, the stronger the snapping effect
    final snapStrength = accuracy * SNAP_SMOOTHING_FACTOR;
    return detectedFreq * (1 - snapStrength) + expectedFreq * snapStrength;
  }

  void _updateFlameGame() {
    if (_flameGame != null) {
      _flameGame!.practiceNotes = _practiceNotes;
      _flameGame!.userPitchPoints = List.of(_userPitchPoints);
      _flameGame!.activeNote = _currentActiveNote;
      _flameGame!.audioSmoothMs = _audioSmoothMs;
      // Optionally: _flameGame!.size = Vector2(_screenWidth, _screenHeight);
    }
  }

  Future<void> _stopMicrophoneListening() async {
    await _microphoneService.stopListening();
    if (mounted) setState(() {
      _isRecording = false;
    });
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '00:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorScreen();
    if (!_isSetupComplete) return _buildLoadingScreen();

    if (_screenWidth == 0) {
      _screenWidth = MediaQuery.of(context).size.width;
      _screenHeight = MediaQuery.of(context).size.height;
      // ensure flame's internal size matches (optional, not critical)
    }

    return WillPopScope(
      onWillPop: () async {
        _finishSession();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2E4C),
        body: SafeArea(
          child: Stack(
            children: [
              GameWidget(game: _flameGame!),
              _buildTopUI(),
              _buildBottomUI(),
              _buildNoteLabels(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopUI() {
    return Positioned(
      top: 15,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.lesson.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_getCurrentAndUpcomingSwars(),
              style: const TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String _getCurrentAndUpcomingSwars() {
    String currentSwar = "";
    String nextSwar = "";
    final smoothPositionMs = _audioSmoothMs;
    if (_currentActiveNote != null) {
      currentSwar = _currentActiveNote!.swarNotation.isNotEmpty
          ? _currentActiveNote!.swarNotation
          : _currentActiveNote!.note;
    }
    PracticeNote? nextNote;
    int currentIndex =
    _currentActiveNote != null ? _practiceNotes.indexOf(_currentActiveNote!) : -1;
    if (currentIndex != -1 && currentIndex < _practiceNotes.length - 1) {
      nextNote = _practiceNotes[currentIndex + 1];
    } else {
      try {
        nextNote = _practiceNotes
            .firstWhere((note) => note.startTime > smoothPositionMs);
      } catch (e) {
        nextNote = null;
      }
    }
    if (nextNote != null) {
      nextSwar = nextNote.swarNotation.isNotEmpty
          ? nextNote.swarNotation
          : nextNote.note;
    }
    if (currentSwar.isEmpty && nextSwar.isEmpty) return " ";
    if (currentSwar.isNotEmpty && nextSwar.isEmpty) return currentSwar;
    return "$currentSwar  →  $nextSwar";
  }

  Widget _buildNoteLabels() {
    if (_screenHeight == 0) return Container();
    final double graphTop = _screenHeight * 0.1;
    final double graphHeight = _screenHeight * 0.8;
    final notes = ['Ṡ', 'N', 'D', 'P', 'M', 'G', 'R', 'S'];
    return Positioned(
      left: 15,
      top: graphTop,
      height: graphHeight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: notes
            .map((note) => Text(note,
            style: const TextStyle(
                color: Colors.white54, fontWeight: FontWeight.bold)))
            .toList(),
      ),
    );
  }

  Widget _buildBottomUI() {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            final position = _duration * _animationController.value;
            final remaining = _duration - position;
            return Row(
              children: [
                Text(_formatDuration(position),
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: LinearProgressIndicator(
                      value: _animationController.value,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                    ),
                  ),
                ),
                Text('-${_formatDuration(remaining)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            );
          }),
    );
  }

  double _frequencyToY(double frequency, double containerHeight) {
    const double minFreq = 80.0;
    const double maxFreq = 800.0;
    final normalizedFreq = (frequency - minFreq) / (maxFreq - minFreq);
    final clampedFreq = normalizedFreq.clamp(0.0, 1.0);
    return (containerHeight * 0.85) * (1.0 - clampedFreq) +
        (containerHeight * 0.075);
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2E4C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.yellowAccent)),
            SizedBox(height: 20),
            Text('Setting up your practice session...',
                style: TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2E4C),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
              const SizedBox(height: 20),
              const Text('Error Loading Session',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text(_errorMessage,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _startSequentialInitialization();
                },
                child: const Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
