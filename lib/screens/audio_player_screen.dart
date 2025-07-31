import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Add this import
import 'package:just_audio/just_audio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../models/lesson_model.dart';
import '../services/auth_service.dart';
import '../services/revenuecat_service.dart';

class AudioPlayerScreen extends StatefulWidget {
  final Lesson lesson;

  const AudioPlayerScreen({
    Key? key,
    required this.lesson,
  }) : super(key: key);

  @override
  _AudioPlayerScreenState createState() => _AudioPlayerScreenState();
}

class _AudioPlayerScreenState extends State<AudioPlayerScreen> {
  late AudioPlayer _audioPlayer;
  final AuthService _authService = AuthService();
  final RevenueCatService _revenueCatService = RevenueCatService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  // Practice time tracking variables
  DateTime? _sessionStartTime;
  DateTime? _lastPlayTime;
  Duration _totalListeningTime = Duration.zero;
  bool _isPlaying = false;
  int _lastUpdatedMinutes = 0;
  Timer? _practiceUpdateTimer;

  // Streak-related variables
  int _currentStreak = 0;
  bool _hasCheckedStreakToday = false;

  // Subscription status
  bool _hasActiveSubscription = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeServices();
    _initializeAudio();
    _checkAndUpdateStreak();
  }

  Future<void> _initializeServices() async {
    try {
      await _revenueCatService.initialize();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _hasActiveSubscription = await _revenueCatService.checkSubscriptionStatus(user.uid);
        print('🔐 Subscription status: ${_hasActiveSubscription ? "Premium" : "Free"}');
      }
    } catch (e) {
      print('Error initializing RevenueCat service: $e');
    }
  }

  Future<void> _checkAndUpdateStreak() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !_hasCheckedStreakToday) {
        await _authService.updatePracticeStreak(user.uid);
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final currentStreak = userData['practiceStreak'] as int? ?? 0;
          setState(() {
            _currentStreak = currentStreak;
          });
          _hasCheckedStreakToday = true;
          print('📊 Current streak: $currentStreak');
        }
      }
    } catch (e) {
      print('Error checking streak: $e');
    }
  }

  void _showStreakMilestoneDialog(int streak) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('Streak Milestone! 🎉'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Amazing! You\'ve practiced for $streak consecutive days!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$streak Day Streak',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Keep up the great work!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showStreakResetDialog(int previousStreak) {
    if (previousStreak > 1) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.refresh, color: Colors.blue),
              SizedBox(width: 8),
              Text('Streak Reset'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Your $previousStreak-day streak has been reset, but don\'t worry!',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text(
                'Starting fresh today. Every expert was once a beginner!',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Let\'s Go!'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _initializeAudio() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      await _audioPlayer.setAudioSource(
        AudioSource.uri(Uri.parse(widget.lesson.audioUrl)),
      );

      _audioPlayer.durationStream.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration ?? Duration.zero;
          });
        }
      });

      _audioPlayer.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          final wasPlaying = _isPlaying;
          final isNowPlaying = state.playing;
          final processingState = state.processingState;

          setState(() {
            _isLoading = processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering;
            _isPlaying = isNowPlaying;
          });

          if (processingState == ProcessingState.completed) {
            _handleTrackCompletion();
          } else {
            _handlePlaybackStateChange(wasPlaying, isNowPlaying);
          }
        }
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load audio. Please check your connection.';
      });
    }
  }

  void _handlePlaybackStateChange(bool wasPlaying, bool isNowPlaying) {
    if (isNowPlaying && !wasPlaying) {
      _sessionStartTime ??= DateTime.now();
      _lastPlayTime = DateTime.now();
      _startRealTimeTracking();
    } else if (wasPlaying && !isNowPlaying) {
      _stopRealTimeTracking();
      if (_lastPlayTime != null) {
        final listeningDuration = DateTime.now().difference(_lastPlayTime!);
        _totalListeningTime += listeningDuration;
      }
    }
  }

  void _startRealTimeTracking() {
    _stopRealTimeTracking();
    _practiceUpdateTimer = Timer.periodic(Duration(seconds: 60), (timer) {
      if (_isPlaying && _lastPlayTime != null) {
        final now = DateTime.now();
        final listeningDuration = now.difference(_lastPlayTime!);
        _totalListeningTime += listeningDuration;
        _lastPlayTime = now;
        _checkAndUpdatePracticeMinutes();
      }
    });
  }

  void _stopRealTimeTracking() {
    _practiceUpdateTimer?.cancel();
    _practiceUpdateTimer = null;
  }

  Future<void> _handleTrackCompletion() async {
    _stopRealTimeTracking();
    if (_lastPlayTime != null) {
      final finalDuration = DateTime.now().difference(_lastPlayTime!);
      _totalListeningTime += finalDuration;
    }
    await _audioPlayer.seek(Duration.zero);
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _position = Duration.zero;
        _isPlaying = false;
      });
    }
  }

  Future<void> _checkAndUpdatePracticeMinutes() async {
    final totalMinutes = _totalListeningTime.inMinutes;
    final minutesToAdd = totalMinutes - _lastUpdatedMinutes;

    if (minutesToAdd > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          final success = await _revenueCatService.addPracticeMinutes(user.uid, minutesToAdd);
          if (success) {
            _lastUpdatedMinutes = totalMinutes;
            print('🎵 Audio listening minutes updated: $minutesToAdd minutes added');
            _hasActiveSubscription = await _revenueCatService.checkSubscriptionStatus(user.uid);
            await _authService.updatePracticeStreak(user.uid);
          } else {
            print('⚠️ Free user has reached 15-minute limit or add failed');
            if (!_hasActiveSubscription) {
              final remainingMinutes = await _revenueCatService.getRemainingFreeMinutes(user.uid);
              if (remainingMinutes <= 0) {
                _showLimitReachedDialog();
              }
            }
          }
        } catch (e) {
          print('Error updating practice minutes: $e');
        }
      }
    }
  }

  void _showLimitReachedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.timer, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Text('Free Time Used Up!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve used your 15 free minutes for today.',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Upgrade to Premium for unlimited listening or try again tomorrow!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/subscription');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Upgrade', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopRealTimeTracking();
    _finalizeListeningSession();
    _audioPlayer.dispose();
    _revenueCatService.dispose();
    super.dispose();
  }

  Future<void> _finalizeListeningSession() async {
    _stopRealTimeTracking();
    if (_isPlaying && _lastPlayTime != null) {
      final now = DateTime.now();
      final remainingDuration = now.difference(_lastPlayTime!);
      _totalListeningTime += remainingDuration;
    }

    final totalMinutes = _totalListeningTime.inMinutes;
    final minutesToAdd = totalMinutes - _lastUpdatedMinutes;

    if (minutesToAdd > 0) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        try {
          await _revenueCatService.addPracticeMinutes(user.uid, minutesToAdd);
          await _authService.updatePracticeStreak(user.uid);
          print('🎵 Final audio session update: $minutesToAdd minutes');
        } catch (e) {
          print('Error in final session update: $e');
        }
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F3E9),
      // Remove the explicit AppBar and use a SafeArea with custom header
      body: SafeArea(
        child: Column(
          children: [
            _buildCustomAppBar(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
    );
  }

  // Custom app bar that respects safe area
  Widget _buildCustomAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B35)),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              'Audio Player',
              style: TextStyle(
                color: Color(0xFFFF6B35),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Show streak indicator
          if (_currentStreak > 0)
            Container(
              margin: EdgeInsets.only(right: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '$_currentStreak',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          // Show subscription status indicator
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hasActiveSubscription
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasActiveSubscription ? Icons.diamond : Icons.timer,
                  color: _hasActiveSubscription ? Colors.green : Colors.orange,
                  size: 14,
                ),
                SizedBox(width: 4),
                Text(
                  _hasActiveSubscription ? 'PRO' : '${_totalListeningTime.inMinutes}m',
                  style: TextStyle(
                    color: _hasActiveSubscription ? Colors.green : Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[300],
            ),
            SizedBox(height: 16),
            Text(
              'Error Loading Audio',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _errorMessage,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initializeAudio,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35),
              ),
              child: Text(
                'Retry',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          _buildLessonInfoCard(),
          SizedBox(height: 40),
          Expanded(
            child: _buildAudioControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonInfoCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.audiotrack,
                  color: Color(0xFFFF6B35),
                  size: 30,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.lesson.title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.lesson.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip(
                widget.lesson.difficulty,
                _getDifficultyColor(widget.lesson.difficulty),
              ),
              _buildInfoChip(
                '${widget.lesson.duration} min',
                Colors.grey[600]!,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Color(0xFF4CAF50);
      case 'intermediate':
        return Color(0xFF2196F3);
      case 'advanced':
        return Color(0xFF9C27B0);
      default:
        return Color(0xFFFF6B35);
    }
  }

  Widget _buildAudioControls() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildProgressSlider(),
        SizedBox(height: 30),
        _buildPlayButton(),
        SizedBox(height: 30),
        _buildTimeDisplay(),
        SizedBox(height: 40),
        _buildAdditionalControls(),
      ],
    );
  }

  Widget _buildProgressSlider() {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Color(0xFFFF6B35),
            inactiveTrackColor: Colors.grey[300],
            thumbColor: Color(0xFFFF6B35),
            overlayColor: Color(0xFFFF6B35).withOpacity(0.2),
            trackHeight: 4,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: _getSliderValue(),
            min: 0.0,
            max: _getSliderMax(),
            onChanged: (value) {
              if (_duration.inMilliseconds > 0) {
                final seekPosition = Duration(
                  milliseconds: (value * _duration.inMilliseconds).round(),
                );
                _audioPlayer.seek(seekPosition);
              }
            },
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  double _getSliderValue() {
    if (_duration.inMilliseconds <= 0) return 0.0;
    final progress = _position.inMilliseconds / _duration.inMilliseconds;
    return progress.clamp(0.0, 1.0);
  }

  double _getSliderMax() {
    return 1.0;
  }

  Widget _buildPlayButton() {
    return StreamBuilder<PlayerState>(
      stream: _audioPlayer.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState?.playing ?? false;
        final processingState = playerState?.processingState ?? ProcessingState.idle;

        return Container(
          width: 80,
          height: 80,
          child: ElevatedButton(
            onPressed: _isLoading ? null : () {
              if (isPlaying) {
                _audioPlayer.pause();
              } else {
                _audioPlayer.play();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              shape: CircleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: _isLoading || processingState == ProcessingState.loading
                ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
                : Icon(
              isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 36,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimeDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.access_time,
            color: Color(0xFFFF6B35),
            size: 16,
          ),
          SizedBox(width: 8),
          Text(
            '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildControlButton(
          icon: Icons.replay,
          onTap: () async {
            await _audioPlayer.seek(Duration.zero);
            if (mounted) {
              setState(() {
                _position = Duration.zero;
              });
            }
          },
        ),
        _buildControlButton(
          icon: Icons.stop,
          onTap: () {
            _audioPlayer.stop();
          },
        ),
        _buildControlButton(
          icon: Icons.forward_10,
          onTap: () {
            final newPosition = _position + Duration(seconds: 10);
            _audioPlayer.seek(
                newPosition > _duration ? _duration : newPosition);
          },
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: Color(0xFFFF6B35),
          size: 24,
        ),
      ),
    );
  }
}