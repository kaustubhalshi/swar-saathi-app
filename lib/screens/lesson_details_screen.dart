import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/lesson_service.dart';
import '../services/revenuecat_service.dart'; // Updated import
import '../models/lesson_model.dart';
import '../screens/subscription_screen.dart';
import 'audio_player_screen.dart';
import 'karaoke_flame_game_screen.dart';

class LessonDetailsScreen extends StatefulWidget {
  final String genre;
  final String title;

  const LessonDetailsScreen({
    Key? key,
    required this.genre,
    required this.title,
  }) : super(key: key);

  @override
  _LessonDetailsScreenState createState() => _LessonDetailsScreenState();
}

class _LessonDetailsScreenState extends State<LessonDetailsScreen> {
  final LessonService _lessonService = LessonService();
  final RevenueCatService _revenueCatService = RevenueCatService(); // Updated service
  List<Lesson> _lessons = [];
  bool _isLoading = true;
  String? _error;
  bool _hasActiveSubscription = false; // Track subscription status
  int _remainingFreeMinutes = 15; // Track remaining free minutes

  @override
  void initState() {
    super.initState();
    _loadLessons();
    _initializeRevenueCatService();
  }

  Future<void> _initializeRevenueCatService() async {
    try {
      await _revenueCatService.initialize();
      await _checkSubscriptionStatus();
    } catch (e) {
      print('Error initializing RevenueCat service: $e');
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        _hasActiveSubscription = await _revenueCatService.checkSubscriptionStatus(user.uid);
        if (!_hasActiveSubscription) {
          _remainingFreeMinutes = await _revenueCatService.getRemainingFreeMinutes(user.uid);
        }

        if (mounted) {
          setState(() {});
        }

        print('🔐 Subscription status: ${_hasActiveSubscription ? "Premium" : "Free"}');
        if (!_hasActiveSubscription) {
          print('⏰ Remaining free minutes: $_remainingFreeMinutes');
        }
      } catch (e) {
        print('Error checking subscription status: $e');
      }
    }
  }

  Future<void> _loadLessons() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final lessons = await _lessonService.getLessonsByGenre(widget.genre);

      setState(() {
        _lessons = lessons;
        _isLoading = false;
      });

      // Check subscription status after loading lessons
      await _checkSubscriptionStatus();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkPracticePermissionAndProceed(Lesson lesson, {bool isAudio = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showErrorDialog('Please sign in to continue');
      return;
    }

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
          ),
        ),
      );

      final permission = await _revenueCatService.checkPracticePermission(user.uid);

      // Hide loading
      Navigator.pop(context);

      if (permission['canPractice'] == true) {
        // User can practice, proceed to lesson
        if (isAudio) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AudioPlayerScreen(lesson: lesson),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => KaraokePracticeScreen(lesson: lesson),
            ),
          );
        }
      } else {
        // User cannot practice, show upgrade dialog
        _showUpgradeDialog(permission['message'] ?? 'Upgrade required');
      }
    } catch (e) {
      // Hide loading if still showing
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      _showErrorDialog('Error checking permissions: $e');
    }
  }

  void _showUpgradeDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.timer, color: Color(0xFFFF6B35)),
            SizedBox(width: 8),
            Expanded(child: Text('Practice Time Limit Reached')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock,
              color: Color(0xFFFF6B35),
              size: 48,
            ),
            SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.diamond, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Upgrade to Premium for unlimited practice!',
                      style: TextStyle(
                        color: Color(0xFFFF6B35),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Try Tomorrow',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(showUpgradeDialog: false),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF6B35),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Upgrade Now',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF7F3E9),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFFFF6B35)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          // Subscription status indicator
          Container(
            margin: EdgeInsets.only(right: 8, top: 8, bottom: 8),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _hasActiveSubscription
                  ? Colors.green.withOpacity(0.1)
                  : Color(0xFFFF6B35).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _hasActiveSubscription ? Icons.diamond : Icons.timer,
                  color: _hasActiveSubscription ? Colors.green : Color(0xFFFF6B35),
                  size: 16,
                ),
                SizedBox(width: 4),
                Text(
                  _hasActiveSubscription ? 'PRO' : '${_remainingFreeMinutes}m',
                  style: TextStyle(
                    color: _hasActiveSubscription ? Colors.green : Color(0xFFFF6B35),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.diamond, color: Color(0xFFFF6B35)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SubscriptionScreen(),
                ),
              );

              // Refresh subscription status when returning from subscription screen
              if (result == true || result == null) {
                await _checkSubscriptionStatus();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
            ),
            SizedBox(height: 16),
            Text(
              'Loading lessons...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
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
              'Error loading lessons',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadLessons,
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

    if (_lessons.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.music_off,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No lessons found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Lessons for ${widget.title} will be added soon.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadLessons,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35),
              ),
              child: Text(
                'Refresh',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadLessons();
        await _checkSubscriptionStatus();
      },
      color: Color(0xFFFF6B35),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(20),
              itemCount: _lessons.length,
              itemBuilder: (context, index) {
                final lesson = _lessons[index];
                return _buildLessonCard(lesson, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(Lesson lesson, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          _showLessonDialog(lesson);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _getLessonColor(lesson.difficulty).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _getLessonColor(lesson.difficulty),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        // Premium indicator if needed
                        if (!_hasActiveSubscription && _remainingFreeMinutes <= 0)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFFFF6B35).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock, size: 12, color: Color(0xFFFF6B35)),
                                SizedBox(width: 2),
                                Text(
                                  'PRO',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      lesson.description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        _buildDifficultyChip(lesson.difficulty),
                        SizedBox(width: 8),
                        if (lesson.duration > 0) ...[
                          Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${lesson.duration} min',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                color: (!_hasActiveSubscription && _remainingFreeMinutes <= 0)
                    ? Colors.grey[400]
                    : Color(0xFFFF6B35),
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(String difficulty) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getLessonColor(difficulty).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        difficulty,
        style: TextStyle(
          color: _getLessonColor(difficulty),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getLessonColor(String difficulty) {
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

  void _showLessonDialog(Lesson lesson) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          lesson.title,
          style: TextStyle(
            color: Color(0xFFFF6B35),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lesson.description,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.5,
              ),
            ),
            if (lesson.content.isNotEmpty) ...[
              SizedBox(height: 16),
              Text(
                'Lesson Content:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 8),
              Text(
                lesson.content,
                style: TextStyle(
                  color: Colors.grey[700],
                  height: 1.4,
                ),
              ),
            ],
            // Subscription status indicator in dialog
            if (!_hasActiveSubscription && _remainingFreeMinutes <= 0) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock, color: Color(0xFFFF6B35), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Premium required - Free minutes used up',
                        style: TextStyle(
                          color: Color(0xFFFF6B35),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (lesson.audioUrl.isNotEmpty) ...[
              SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.audiotrack, color: Color(0xFFFF6B35), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Audio available',
                    style: TextStyle(
                      color: Color(0xFFFF6B35),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
            if (lesson.practiceUrl.isNotEmpty) ...[
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.fitness_center, color: Color(0xFF4CAF50), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Practice exercises available',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Close',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          if (lesson.audioUrl.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _checkPracticePermissionAndProceed(lesson, isAudio: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6B35),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Listen',
                style: TextStyle(color: Colors.white),
              ),
            ),
          if (lesson.practiceUrl.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _checkPracticePermissionAndProceed(lesson, isAudio: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CAF50),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Practice',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Error'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _revenueCatService.dispose(); // Updated disposal
    super.dispose();
  }
}