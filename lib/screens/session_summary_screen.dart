import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/revenuecat_service.dart';

class SessionSummaryScreen extends StatefulWidget {
  final int practiceMinutes;
  final String lessonTitle;
  final double averageAccuracy;
  final int totalNotesAttempted;
  final int correctNotes;
  final List<double> pitchAccuracyHistory;

  const SessionSummaryScreen({
    Key? key,
    required this.practiceMinutes,
    required this.lessonTitle,
    required this.averageAccuracy,
    required this.totalNotesAttempted,
    required this.correctNotes,
    required this.pitchAccuracyHistory,
  }) : super(key: key);

  // Helper method to get day key
  String _getDayKey(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  @override
  _SessionSummaryScreenState createState() => _SessionSummaryScreenState();
}

class _SessionSummaryScreenState extends State<SessionSummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreAnimationController;
  late AnimationController _progressAnimationController;
  late Animation<double> _scoreAnimation;
  late Animation<double> _progressAnimation;

  final AuthService _authService = AuthService();
  final RevenueCatService _revenueCatService = RevenueCatService();
  bool _isUpdatingProgress = false;
  UserModel? _updatedUser;
  int _finalScore = 0;
  bool _hasActiveSubscription = false;
  Map<String, dynamic>? _subscriptionInfo;

  @override
  void initState() {
    super.initState();
    _scoreAnimationController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _progressAnimationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scoreAnimationController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressAnimationController,
      curve: Curves.easeInOut,
    ));

    _calculateFinalScore();
    _initializeServices();
    _updateUserProgress();

    // Start animations
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) _scoreAnimationController.forward();
    });
    Future.delayed(Duration(milliseconds: 800), () {
      if (mounted) _progressAnimationController.forward();
    });
  }

  Future<void> _initializeServices() async {
    try {
      await _revenueCatService.initialize();

      // Get subscription info
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _hasActiveSubscription = await _revenueCatService.checkSubscriptionStatus(user.uid);
        _subscriptionInfo = await _revenueCatService.getSubscriptionInfo(user.uid);
        print('💎 Subscription status initialized: $_hasActiveSubscription');
      }
    } catch (e) {
      print('❌ Error initializing RevenueCat service: $e');
    }
  }

  void _calculateFinalScore() {
    // Improved Scoring Algorithm - Much stricter
    // Base accuracy score (40% weight) - exponential curve makes high accuracy harder
    double accuracyScore = 0;
    if (widget.averageAccuracy >= 95) {
      accuracyScore = 40; // Perfect accuracy gets full points
    } else if (widget.averageAccuracy >= 90) {
      accuracyScore = 35; // Excellent
    } else if (widget.averageAccuracy >= 85) {
      accuracyScore = 30; // Very good
    } else if (widget.averageAccuracy >= 80) {
      accuracyScore = 25; // Good
    } else if (widget.averageAccuracy >= 75) {
      accuracyScore = 20; // Average
    } else if (widget.averageAccuracy >= 70) {
      accuracyScore = 15; // Below average
    } else {
      accuracyScore = (widget.averageAccuracy / 70) * 15; // Poor performance
    }

    // Completion rate score (25% weight) - also stricter
    double completionRate = widget.correctNotes / widget.totalNotesAttempted;
    double completionScore = 0;
    if (completionRate >= 0.95) {
      completionScore = 25;
    } else if (completionRate >= 0.90) {
      completionScore = 22;
    } else if (completionRate >= 0.85) {
      completionScore = 20;
    } else if (completionRate >= 0.80) {
      completionScore = 18;
    } else if (completionRate >= 0.75) {
      completionScore = 15;
    } else {
      completionScore = completionRate * 20; // Linear below 75%
    }

    // Consistency score (25% weight) - penalizes fluctuation heavily
    double consistencyScore = _calculateConsistency() * 25;

    // Practice time bonus (10% weight) - rewards dedicated practice
    double timeBonus = 0;
    if (widget.practiceMinutes >= 30) {
      timeBonus = 10;
    } else if (widget.practiceMinutes >= 20) {
      timeBonus = 8;
    } else if (widget.practiceMinutes >= 15) {
      timeBonus = 6;
    } else if (widget.practiceMinutes >= 10) {
      timeBonus = 4;
    } else {
      timeBonus = (widget.practiceMinutes / 10) * 4;
    }

    _finalScore = (accuracyScore + completionScore + consistencyScore + timeBonus).round();
    _finalScore = _finalScore.clamp(0, 100);

    print('🎯 Score breakdown:');
    print('🎯 Accuracy Score: $accuracyScore (${widget.averageAccuracy}%)');
    print('🎯 Completion Score: $completionScore (${(completionRate * 100).toStringAsFixed(1)}%)');
    print('🎯 Consistency Score: $consistencyScore');
    print('🎯 Time Bonus: $timeBonus (${widget.practiceMinutes} min)');
    print('🎯 Final Score: $_finalScore');
  }

  double _calculateConsistency() {
    if (widget.pitchAccuracyHistory.length < 2) return 0.5; // Default for insufficient data

    double sum = 0;
    for (int i = 1; i < widget.pitchAccuracyHistory.length; i++) {
      sum += (widget.pitchAccuracyHistory[i] - widget.pitchAccuracyHistory[i-1]).abs();
    }

    double averageVariation = sum / (widget.pitchAccuracyHistory.length - 1);

    // More aggressive consistency calculation
    // Variation above 20% heavily penalized
    double consistencyScore;
    if (averageVariation <= 5) {
      consistencyScore = 1.0; // Excellent consistency
    } else if (averageVariation <= 10) {
      consistencyScore = 0.9; // Very good
    } else if (averageVariation <= 15) {
      consistencyScore = 0.7; // Good
    } else if (averageVariation <= 20) {
      consistencyScore = 0.5; // Average
    } else if (averageVariation <= 30) {
      consistencyScore = 0.3; // Poor
    } else {
      consistencyScore = 0.1; // Very poor
    }

    return consistencyScore;
  }

  // ⭐ FIXED: Single update path - only uses AuthService
  Future<void> _updateUserProgress() async {
    if (!mounted) return;

    setState(() {
      _isUpdatingProgress = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        print('🔥 Starting progress update for user: ${user.uid}');
        print('🔥 Practice minutes to add: ${widget.practiceMinutes}');

        // Get current user data first to see the before state
        final beforeDoc = await _authService.getUserDocument(user.uid);
        if (beforeDoc != null) {
          final beforeUser = UserModel.fromFirestore(beforeDoc);
          print('📊 BEFORE update - Streak: ${beforeUser.practiceStreak}, Practice Minutes: ${beforeUser.totalPracticeMinutes}, Free Minutes Used: ${beforeUser.freePracticeMinutesUsed}, Lessons Completed: ${beforeUser.lessonsCompleted}');
        }

        // Check subscription status using RevenueCat (for display purposes only)
        _hasActiveSubscription = await _revenueCatService.checkSubscriptionStatus(user.uid);
        print('💎 User subscription status: ${_hasActiveSubscription ? "Premium" : "Free"}');

        // Generate a unique lesson ID for this session
        final lessonId = 'lesson_${DateTime.now().millisecondsSinceEpoch}';

        // ⭐ SINGLE UPDATE: Record practice session (this handles everything)
        print('📝 Recording practice session (includes minutes, streak, lesson completion)...');
        final sessionRecorded = await _authService.recordPracticeSession(
          user.uid,
          lessonId: lessonId,
          lessonTitle: widget.lessonTitle,
          practiceMinutes: widget.practiceMinutes,
          averageAccuracy: widget.averageAccuracy,
          totalNotes: widget.totalNotesAttempted,
          correctNotes: widget.correctNotes,
          finalScore: _finalScore,
        );
        print('✅ Practice session recorded: $sessionRecorded');

        // Check if free limit was reached during the session
        if (!_hasActiveSubscription) {
          final permission = await _revenueCatService.checkPracticePermission(user.uid);
          if (permission['canPractice'] == false) {
            print('⚠️ Free limit reached during session');
            _showFreeLimitReachedDialog();
          }
        }

        // Wait for Firestore to propagate changes
        print('⏳ Waiting for Firestore to propagate changes...');
        await Future.delayed(Duration(milliseconds: 2000));

        // Get updated user data and subscription info
        final userDoc = await _authService.getUserDocument(user.uid);
        _subscriptionInfo = await _revenueCatService.getSubscriptionInfo(user.uid);

        if (userDoc != null) {
          final updatedUser = UserModel.fromFirestore(userDoc);
          print('📊 AFTER update - Streak: ${updatedUser.practiceStreak}, Practice Minutes: ${updatedUser.totalPracticeMinutes}, Free Minutes Used: ${updatedUser.freePracticeMinutesUsed}, Lessons Completed: ${updatedUser.lessonsCompleted}');

          if (mounted) {
            setState(() {
              _updatedUser = updatedUser;
            });
          }
        } else {
          print('❌ Could not retrieve updated user data');
        }
      } else {
        print('❌ No authenticated user found');
      }
    } catch (e) {
      print('❌ Error updating user progress: $e');
      print('Stack trace: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingProgress = false;
        });
      }
    }
  }

  void _showFreeLimitReachedDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Color(0xFF2D1B69),
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Free Practice Limit Reached',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve used up your 15 minutes of free practice for today!',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Subscribe to Premium for unlimited practice or try again tomorrow.',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Try Tomorrow', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToSubscription();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('Subscribe', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _navigateToSubscription() {
    // Navigate to subscription screen
    // You'll need to import your SubscriptionScreen
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => SubscriptionScreen(
    //       currentUser: _updatedUser,
    //       showUpgradeDialog: true,
    //     ),
    //   ),
    // );
  }

  @override
  void dispose() {
    _scoreAnimationController.dispose();
    _progressAnimationController.dispose();
    _revenueCatService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1A0E3D),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Column(
            children: [
              SizedBox(height: 20),
              _buildHeader(),
              SizedBox(height: 30),
              _buildScoreCard(),
              SizedBox(height: 30),
              _buildStatsGrid(),
              SizedBox(height: 30),
              _buildProgressUpdate(),
              SizedBox(height: 30),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.yellow, Colors.orange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.yellow.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(
            Icons.music_note,
            size: 40,
            color: Colors.black,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'Practice Session Complete!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          widget.lessonTitle,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildScoreCard() {
    return AnimatedBuilder(
      animation: _scoreAnimation,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF4C1D95),
                Color(0xFF7C3AED),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.purple.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                'Your Score',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: CircularProgressIndicator(
                      value: _scoreAnimation.value * (_finalScore / 100),
                      strokeWidth: 8,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getScoreColor(_finalScore),
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      Text(
                        '${(_scoreAnimation.value * _finalScore).round()}',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'out of 100',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Text(
                _getScoreMessage(_finalScore),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid() {
    return AnimatedBuilder(
      animation: _progressAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _progressAnimation.value),
          child: Opacity(
            opacity: _progressAnimation.value,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Practice Time',
                        '${widget.practiceMinutes} min',
                        Icons.access_time,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Accuracy',
                        '${widget.averageAccuracy.toStringAsFixed(1)}%',
                        Icons.tune,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Notes Hit',
                        '${widget.correctNotes}/${widget.totalNotesAttempted}',
                        Icons.music_note,
                        Colors.orange,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Consistency',
                        '${(_calculateConsistency() * 100).toStringAsFixed(0)}%',
                        Icons.trending_up,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressUpdate() {
    if (_isUpdatingProgress) {
      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.yellow),
            ),
            SizedBox(height: 16),
            Text(
              'Updating your progress...',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_updatedUser != null) {
      final remainingMinutes = _subscriptionInfo?['remainingFreeMinutes'] ?? 0;
      final freePracticeUsed = _subscriptionInfo?['freePracticeMinutesUsed'] ?? 0;

      return Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.withOpacity(0.2),
              Colors.teal.withOpacity(0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.celebration,
              color: Colors.green,
              size: 32,
            ),
            SizedBox(height: 12),
            Text(
              'Progress Updated!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${_updatedUser!.practiceStreak}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Day Streak',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_updatedUser!.totalPracticeMinutes}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Minutes Today',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${_updatedUser!.lessonsCompleted}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Lessons Done',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // Show subscription status and free minutes usage
            SizedBox(height: 16),
            // Container(
            //   padding: EdgeInsets.all(12),
            //   decoration: BoxDecoration(
            //     color: _hasActiveSubscription
            //         ? Colors.green.withOpacity(0.2)
            //         : Colors.orange.withOpacity(0.2),
            //     borderRadius: BorderRadius.circular(8),
            //     border: Border.all(
            //         color: _hasActiveSubscription
            //             ? Colors.green.withOpacity(0.3)
            //             : Colors.orange.withOpacity(0.3)
            //     ),
            //   ),
            //   child: Row(
            //     mainAxisAlignment: MainAxisAlignment.center,
            //     children: [
            //       Icon(
            //           _hasActiveSubscription ? Icons.diamond : Icons.timer,
            //           color: _hasActiveSubscription ? Colors.green : Colors.orange,
            //           size: 16
            //       ),
            //       // SizedBox(width: 8),
            //       // Text(
            //       //   _hasActiveSubscription
            //       //       ? 'Premium: Unlimited practice ✨'
            //       //       : 'Free: $remainingMinutes min left today ($freePracticeUsed/15 used)',
            //       //   style: TextStyle(
            //       //     color: Colors.white,
            //       //     fontSize: 14,
            //       //     fontWeight: FontWeight.w500,
            //       //   ),
            //       // ),
            //     ],
            //   ),
            // ),
          ],
        ),
      );
    }

    return Container();
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Go back to lesson list
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow,
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Continue Learning',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
          ),
        ),
        SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // Go back to practice
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.white.withOpacity(0.5)),
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Practice Again',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 85) return Colors.green;
    if (score >= 70) return Colors.lightGreen;
    if (score >= 55) return Colors.yellow;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  String _getScoreMessage(int score) {
    if (score >= 90) return "Outstanding! 🎵🎶🎼🎹🎸🥁🎺🎷🎻🎤🎧🎚\nYou're a natural!";
    if (score >= 80) return "Excellent! ⭐🌟✨💫🔥🎯\nGreat progress!";
    if (score >= 70) return "Good work! 👍👏\nKeep practicing!";
    if (score >= 60) return "Not bad! 👌\nYou're improving!";
    if (score >= 40) return "Keep trying! 🎯🎵🎶🎼🎹🎸\nPractice makes perfect!";
    return "Don't give up! 💪💯\nEvery expert was once a beginner!";
  }
}