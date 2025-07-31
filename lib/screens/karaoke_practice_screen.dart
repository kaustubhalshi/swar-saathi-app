import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/lesson_model.dart';
import '../services/microphone_service.dart';
import '../services/pitch_detection_service.dart';
import '../services/audio_route_service.dart';
import '../services/auth_service.dart';
import 'session_summary_screen.dart';

class KaraokePracticeScreen extends StatefulWidget {
  final Lesson lesson;
  const KaraokePracticeScreen({Key? key, required this.lesson}) : super(key: key);

  @override
  _KaraokePracticeScreenState createState() => _KaraokePracticeScreenState();
}

class _KaraokePracticeScreenState extends State<KaraokePracticeScreen>
    with TickerProviderStateMixin {
  late AudioPlayer _audioPlayer;
  late MicrophoneService _microphoneService;
  late PitchDetectionService _pitchDetectionService;
  final AuthService _authService = AuthService();

  late AnimationController _animationController;
  late Ticker _precisePitchTicker;

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
  double? _lastRawPitch;
  int _lastPitchTimestamp = 0;

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

  // Karaoke constants
  static const double PLAYHEAD_POSITION = 160.0;
  static const int VISIBLE_DURATION_MS = 16000;

  // ENHANCED: Ultra-high precision pitch visualization
  List<PitchPoint> _userPitchPoints = [];
  static const int MAX_PITCH_POINTS = 1200; // Increased for more data
  static const int PITCH_INTERPOLATION_MS = 1; // Interpolate every 1ms

  bool _isSetupComplete = false;
  double _screenWidth = 0;
  double _screenHeight = 0;

  // Enhanced smoothing for millisecond precision
  double? _lastPitchSmoothed;
  List<double> _pitchBuffer = [];
  static const int PITCH_BUFFER_SIZE = 5;

  // Cent tolerance for pitch (in-tune detection)
  static const double TOLERANCE_CENTS = 40.0;

  // High-precision timing
  int _sessionStartMicroseconds = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _audioPlayer = AudioPlayer();
    _microphoneService = MicrophoneService();
    _pitchDetectionService = PitchDetectionService();
    _sessionStartMicroseconds = DateTime.now().microsecondsSinceEpoch;

    // AnimationController for smooth timeline
    _animationController = AnimationController(
      duration: Duration.zero,
      vsync: this,
    );

    // ENHANCED: High-frequency ticker for millisecond-precise updates
    _precisePitchTicker = createTicker(_updatePrecisePitchVisualization);

    _practiceNotes = widget.lesson.practiceNotes;
    _sessionStartTime = DateTime.now();
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
    _precisePitchTicker.dispose();
    _animationController.dispose();
    _audioPlayer.dispose();
    _microphoneService.dispose();
    super.dispose();
  }

  // ENHANCED: Millisecond-precise pitch visualization updater
  void _updatePrecisePitchVisualization(Duration elapsed) {
    if (!_isRecording || _lastRawPitch == null) return;

    final currentMicros = DateTime.now().microsecondsSinceEpoch;
    final sessionMs = (currentMicros - _sessionStartMicroseconds) ~/ 1000;
    final audioPositionMs = _audioPlayer.position.inMilliseconds;

    // Interpolate pitch points at millisecond intervals if needed
    if (_userPitchPoints.isNotEmpty) {
      final lastPoint = _userPitchPoints.last;
      final timeDiff = sessionMs - lastPoint.timestamp;

      // Fill gaps with interpolated points for ultra-smooth visualization
      if (timeDiff > PITCH_INTERPOLATION_MS && timeDiff < 50) {
        for (int i = 1; i < timeDiff; i++) {
          final interpolatedTimestamp = lastPoint.timestamp + i;
          final t = i / timeDiff;
          final interpolatedFreq = lastPoint.frequency * (1 - t) + _lastRawPitch! * t;

          _userPitchPoints.add(PitchPoint(
            frequency: interpolatedFreq,
            timestamp: interpolatedTimestamp,
            confidence: lastPoint.confidence * 0.8, // Slightly lower confidence for interpolated
            inTune: lastPoint.inTune,
          ));
        }
      }
    }

    // Limit points for performance
    if (_userPitchPoints.length > MAX_PITCH_POINTS) {
      _userPitchPoints.removeRange(0, _userPitchPoints.length - MAX_PITCH_POINTS);
    }
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

      // Sync animation with audio position
      _audioPlayer.positionStream.listen((position) {
        if (mounted && _duration.inMilliseconds > 0) {
          _animationController.value =
              position.inMilliseconds / _duration.inMilliseconds;
          _updateCurrentActiveNote(position);
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (!mounted) return;

        if (state.playing) {
          _animationController.forward();
          if (!_isRecording && _microphonePermissionGranted) {
            _startMicrophoneListening();
            _startPracticeTracking();
            _precisePitchTicker.start(); // Start high-precision ticker
          }
        } else {
          _animationController.stop();
          _precisePitchTicker.stop(); // Stop high-precision ticker
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
      _practiceTimer = Timer.periodic(Duration(seconds: 30), (timer) {
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

  bool _isInTune(double userFreq, double targetFreq) {
    if (userFreq <= 0 || targetFreq <= 0) return false;
    final cents = 1200 * (math.log(userFreq / targetFreq) / math.ln2);
    return cents.abs() <= TOLERANCE_CENTS;
  }

  // ENHANCED: Ultra-precise pitch processing with microsecond timestamps
  void _processAudioForPitchDetection(List<double> audioSamples) {
    if (_audioPlayer.playing == false) return;
    if (_currentVolume < 0.01 || audioSamples.length < 1024) return;

    // Use smaller buffer for more frequent updates (reduced from 2048 to 1024)
    final result = _pitchDetectionService.detectPitch(
      audioSamples.sublist(math.max(0, audioSamples.length - 1024)),
      44100,
    );

    // High-precision timestamp
    final currentMicros = DateTime.now().microsecondsSinceEpoch;
    final sessionMs = (currentMicros - _sessionStartMicroseconds) ~/ 1000;

    // Enhanced smoothing with buffer
    double newFreq = result.frequency;
    if (newFreq > 80 && newFreq < 800) { // Valid range
      _pitchBuffer.add(newFreq);
      if (_pitchBuffer.length > PITCH_BUFFER_SIZE) {
        _pitchBuffer.removeAt(0);
      }

      // Multi-stage smoothing
      final bufferAvg = _pitchBuffer.reduce((a, b) => a + b) / _pitchBuffer.length;
      const alpha = 0.25; // More aggressive smoothing for precision

      if (_lastPitchSmoothed != null) {
        newFreq = _lastPitchSmoothed! * (1 - alpha) + bufferAvg * alpha;
      } else {
        newFreq = bufferAvg;
      }
      _lastPitchSmoothed = newFreq;
      _lastRawPitch = newFreq;
    }

    bool inTune = false;
    if (_currentActiveNote != null && result.confidence > 0.5) {
      inTune = _isInTune(newFreq, _currentActiveNote!.frequency);
    }

    // Store pitch point with millisecond precision
    _userPitchPoints.add(PitchPoint(
      frequency: newFreq,
      timestamp: sessionMs,
      confidence: result.confidence,
      inTune: inTune,
    ));

    _detectedFrequency = newFreq;
    _lastPitchTimestamp = sessionMs;
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
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final smoothPosition =
                      _animationController.value * _duration.inMilliseconds;
                  return CustomPaint(
                    size: Size.infinite,
                    painter: MillisecondPrecisionKaraokePainter(
                      practiceNotes: _practiceNotes,
                      userPitchPoints: List.of(_userPitchPoints),
                      smoothPosition: smoothPosition,
                      currentActiveNote: _currentActiveNote,
                      playheadX: PLAYHEAD_POSITION,
                      containerHeight: _screenHeight,
                      visibleDurationMs: VISIBLE_DURATION_MS,
                      frequencyToY: _frequencyToY,
                      sessionStartMicros: _sessionStartMicroseconds,
                    ),
                  );
                },
              ),
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
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: 8),
          Text(_getCurrentAndUpcomingSwars(),
              style: TextStyle(
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
    final smoothPositionMs =
        _animationController.value * _duration.inMilliseconds;

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
            style: TextStyle(
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
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: LinearProgressIndicator(
                      value: _animationController.value,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.yellowAccent),
                    ),
                  ),
                ),
                Text('-${_formatDuration(remaining)}',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
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
          children: [
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
              Icon(Icons.error_outline, color: Colors.redAccent, size: 50),
              SizedBox(height: 20),
              Text('Error Loading Session',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text(_errorMessage,
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _startSequentialInitialization();
                },
                child: Text('Retry'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced PitchPoint with microsecond precision
class PitchPoint {
  final double frequency;
  final int timestamp; // in milliseconds
  final double confidence;
  final bool inTune;

  PitchPoint({
    required this.frequency,
    required this.timestamp,
    required this.confidence,
    this.inTune = false,
  });
}

// ENHANCED: Millisecond-precision painter with advanced interpolation
class MillisecondPrecisionKaraokePainter extends CustomPainter {
  final List<PracticeNote> practiceNotes;
  final List<PitchPoint> userPitchPoints;
  final double smoothPosition;
  final PracticeNote? currentActiveNote;
  final double playheadX;
  final double containerHeight;
  final int visibleDurationMs;
  final double Function(double, double) frequencyToY;
  final int sessionStartMicros;

  static final Paint _gridPaint = Paint()
    ..color = Colors.white.withOpacity(0.1)
    ..strokeWidth = 1.0;

  static final Paint _notePaint = Paint()..style = PaintingStyle.fill;

  static final Paint _playheadPaint = Paint()
    ..color = Colors.orangeAccent
    ..strokeWidth = 2.0;

  MillisecondPrecisionKaraokePainter({
    required this.practiceNotes,
    required this.userPitchPoints,
    required this.smoothPosition,
    required this.currentActiveNote,
    required this.playheadX,
    required this.containerHeight,
    required this.visibleDurationMs,
    required this.frequencyToY,
    required this.sessionStartMicros,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGridLines(canvas, size);
    _drawPracticeNotes(canvas, size);
    _drawMillisecondPrecisionPitchLine(canvas, size);
    _drawPlayhead(canvas, size);
  }

  void _drawGridLines(Canvas canvas, Size size) {
    final double graphTop = size.height * 0.1;
    final double graphBottom = size.height * 0.9;
    final double graphHeight = graphBottom - graphTop;
    for (int i = 0; i <= 8; i++) {
      final y = graphTop + (i / 8) * graphHeight;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        _gridPaint,
      );
    }
  }

  void _drawPracticeNotes(Canvas canvas, Size size) {
    final pixelsPerMs = size.width / visibleDurationMs;

    for (final note in practiceNotes) {
      final startX =
          playheadX + (note.startTime - smoothPosition) * pixelsPerMs;
      final endX = playheadX + (note.endTime - smoothPosition) * pixelsPerMs;
      if (startX > size.width || endX < 0) continue;

      final y = frequencyToY(note.frequency, containerHeight);
      final noteWidth = endX - startX;
      _notePaint.color = _getNoteColor(note);

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startX, y - 5, noteWidth, 10),
        const Radius.circular(5),
      );
      canvas.drawRRect(rect, _notePaint);
    }
  }

  // ENHANCED: Millisecond-precision pitch line with ultra-dense interpolation
  void _drawMillisecondPrecisionPitchLine(Canvas canvas, Size size) {
    if (userPitchPoints.length < 2) return;

    final pixelsPerMs = size.width / visibleDurationMs;
    final minTimestamp = (smoothPosition - visibleDurationMs ~/ 2).toInt();
    final maxTimestamp = (smoothPosition + visibleDurationMs ~/ 2).toInt();

    final pathCorrect = Path();
    final pathWrong = Path();
    bool movedCorrect = false, movedWrong = false;

    // Create ultra-dense interpolation for millisecond-level precision
    for (int i = 0; i < userPitchPoints.length - 1; i++) {
      final p1 = userPitchPoints[i];
      final p2 = userPitchPoints[i + 1];

      if (p2.timestamp < minTimestamp) continue;
      if (p1.timestamp > maxTimestamp) break;

      final x1 = playheadX - (smoothPosition - p1.timestamp) * pixelsPerMs;
      final y1 = frequencyToY(p1.frequency, containerHeight);
      final x2 = playheadX - (smoothPosition - p2.timestamp) * pixelsPerMs;
      final y2 = frequencyToY(p2.frequency, containerHeight);

      // Dense interpolation - create point for every millisecond
      final timeDiff = p2.timestamp - p1.timestamp;
      if (timeDiff > 0) {
        final steps = math.max(timeDiff, 1);
        for (int s = 0; s <= steps; s++) {
          final t = steps == 1 ? 0.0 : s / steps;
          final ix = x1 + (x2 - x1) * t;
          final iy = y1 + (y2 - y1) * t;

          // Smooth transition between in-tune states
          final inTune = t < 0.5 ? p1.inTune : p2.inTune;

          if (inTune) {
            if (!movedCorrect) {
              pathCorrect.moveTo(ix, iy);
              movedCorrect = true;
            } else {
              pathCorrect.lineTo(ix, iy);
            }
          } else {
            if (!movedWrong) {
              pathWrong.moveTo(ix, iy);
              movedWrong = true;
            } else {
              pathWrong.lineTo(ix, iy);
            }
          }
        }
      }
    }

    // Enhanced shadow for better visibility
    final Paint shadowPaint = Paint()
      ..color = Colors.cyanAccent.withOpacity(0.12)
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2);

    if (movedCorrect) canvas.drawPath(pathCorrect, shadowPaint);
    if (movedWrong) canvas.drawPath(pathWrong, shadowPaint);

    // Main lines with anti-aliasing
    final Paint correctPaint = Paint()
      ..color = Colors.green
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final Paint wrongPaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (movedCorrect) canvas.drawPath(pathCorrect, correctPaint);
    if (movedWrong) canvas.drawPath(pathWrong, wrongPaint);
  }

  void _drawPlayhead(Canvas canvas, Size size) {
    final double graphTop = size.height * 0.1;
    final double graphBottom = size.height * 0.9;

    canvas.drawLine(
      Offset(playheadX, graphTop),
      Offset(playheadX, graphBottom),
      _playheadPaint,
    );
  }

  Color _getNoteColor(PracticeNote note) {
    final bool isPassed = note.endTime < smoothPosition;
    final bool isActive = currentActiveNote == note;

    if (isActive) {
      return Colors.orangeAccent;
    } else if (isPassed) {
      return Colors.grey.withOpacity(0.6);
    }
    return Colors.amber.withOpacity(0.8);
  }

  @override
  bool shouldRepaint(MillisecondPrecisionKaraokePainter old) {
    return old.smoothPosition != smoothPosition ||
        old.currentActiveNote != currentActiveNote ||
        old.userPitchPoints.length != userPitchPoints.length;
  }
}
