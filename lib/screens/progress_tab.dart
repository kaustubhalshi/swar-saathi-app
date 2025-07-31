import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class ProgressTab extends StatefulWidget {
  @override
  _ProgressTabState createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  Map<String, dynamic>? _practiceProgress;
  Map<String, int>? _weeklyPractice;
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadProgressData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadProgressData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _authService.getUserDocument(user.uid);
        final progress = await _authService.getDailyPracticeProgress(user.uid);
        final weeklyPractice = await _authService.getWeeklyPracticeSummary(user.uid);

        // Debug prints
        print('🔍 User document exists: ${userDoc?.exists}');
        print('🔍 Progress data: $progress');
        print('🔍 Weekly practice data: $weeklyPractice');

        if (userDoc != null && mounted) {
          final userModel = UserModel.fromFirestore(userDoc);
          print('🔍 User daily goal: ${userModel.dailyGoalMinutes}');
          print('🔍 User total practice minutes: ${userModel.totalPracticeMinutes}');
          print('🔍 User weekly progress: ${userModel.weeklyProgress}');

          setState(() {
            _currentUser = userModel;
            _practiceProgress = progress;
            _weeklyPractice = weeklyPractice;
            _isLoading = false;
          });
          _animationController.forward();
        }
      }
    } catch (e) {
      print('Error loading progress data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProgressData,
      color: Color(0xFFFF6B35),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProgressOverviewCard(),
            SizedBox(height: 25),
            _buildWeeklyProgressChart(),
            SizedBox(height: 25),
            _buildLevelProgressCard(),
            SizedBox(height: 25),
            _buildAchievementsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressOverviewCard() {
    final dailyMinutes = _practiceProgress?['dailyMinutes'] ?? 0;
    final goalMinutes = _practiceProgress?['goalMinutes'] ?? 30;
    final streak = _currentUser?.practiceStreak ?? 0;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _animationController.value),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF4C1D95), Color(0xFF7C3AED)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF7C3AED).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Progress',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            '${_currentUser?.practiceLevel ?? "Beginner"}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildProgressStat('Today', '${dailyMinutes}m', '${goalMinutes}m goal'),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(
                        child: _buildProgressStat('Streak', '${streak}', 'days'),
                      ),
                      Container(width: 1, height: 40, color: Colors.white24),
                      Expanded(
                        child: _buildProgressStat('Total', '${_currentUser?.formattedAllTimeTotal}', 'practiced'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildProgressStat(String label, String value, String subtitle) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.white60,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWeeklyProgressChart() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Weekly Practice',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Container(
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
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _buildWeeklyChartBars(),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                    .map((day) =>
                    Text(
                      day,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildWeeklyChartBars() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dailyGoal = _currentUser?.dailyGoalMinutes ?? 30;
    final now = DateTime.now();
    final todayKey = _getDayKey(now);

    print('🔍 Building chart bars with daily goal: $dailyGoal');
    print('🔍 Weekly practice data: $_weeklyPractice');
    print('🔍 Today is: $todayKey');

    return days.map((day) {
      int minutes = 0;

      // Get minutes for this day
      if (day == todayKey) {
        // For today, use current totalPracticeMinutes
        minutes = _currentUser?.totalPracticeMinutes ?? 0;
        print('🔍 Today ($day): Using current totalPracticeMinutes = $minutes');
      } else {
        // For other days, use stored weekly progress
        minutes = _weeklyPractice?[day] ?? 0;
        print('🔍 Day $day: Using stored progress = $minutes');
      }

      // Calculate progress as percentage of daily goal (0.0 to 1.0+)
      final progress = dailyGoal > 0 ? minutes / dailyGoal : 0.0;

      // Height based on goal completion (max height is 80, min is 8 for visibility)
      final height = progress > 0 ? (progress * 80).clamp(8.0, 80.0) : 8.0;

      print('🔍 Day: $day, Minutes: $minutes, Progress: ${(progress * 100).toStringAsFixed(1)}%, Height: $height');

      // Color based on goal completion
      Color barColor;
      if (minutes == 0) {
        barColor = Colors.grey[300]!;
      } else if (progress >= 1.0) {
        // Goal achieved or exceeded - green
        barColor = Color(0xFF4CAF50);
      } else if (progress >= 0.75) {
        // 75%+ of goal - orange
        barColor = Color(0xFFFF9800);
      } else if (progress >= 0.5) {
        // 50%+ of goal - light orange
        barColor = Color(0xFFFFB74D);
      } else {
        // Less than 50% of goal - primary color
        barColor = Color(0xFFFF6B35);
      }

      return Container(
        width: 24,
        height: 80,
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 24,
          height: height,
          decoration: BoxDecoration(
            color: barColor,
            borderRadius: BorderRadius.circular(4),
            // Add a subtle gradient for completed goals
            gradient: progress >= 1.0 ? LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
            ) : null,
          ),
          child: progress >= 1.0 ?
          // Add a small checkmark icon for completed days
          Center(
            child: Icon(
              Icons.check,
              color: Colors.white,
              size: 12,
            ),
          ) : null,
        ),
      );
    }).toList();
  }

  // Helper method to get day key from DateTime
  String _getDayKey(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  Widget _buildLevelProgressCard() {
    final currentLevel = _currentUser?.practiceLevel ?? 'Beginner';
    final levelProgress = _currentUser?.practiceLevelProgress ?? 0.0;
    final nextLevelInfo = _currentUser?.nextLevelInfo ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Level Progress',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Container(
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Current Level',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        currentLevel,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getLevelColor(currentLevel),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getLevelColor(currentLevel).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getLevelIcon(currentLevel),
                      color: _getLevelColor(currentLevel),
                      size: 24,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              LinearProgressIndicator(
                value: levelProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(_getLevelColor(currentLevel)),
              ),
              SizedBox(height: 12),
              if (nextLevelInfo.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Next: ${nextLevelInfo['nextLevel']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${nextLevelInfo['minutesNeeded']}m to go',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    final achievements = _getAchievements();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1,
          children: achievements.map((achievement) {
            return Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: achievement['unlocked'] ? Colors.white : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: achievement['unlocked']
                      ? achievement['color'].withOpacity(0.3)
                      : Colors.grey[300]!,
                ),
                boxShadow: achievement['unlocked'] ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ] : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    achievement['icon'],
                    color: achievement['unlocked']
                        ? achievement['color']
                        : Colors.grey[400],
                    size: 24,
                  ),
                  SizedBox(height: 8),
                  Text(
                    achievement['title'],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: achievement['unlocked']
                          ? Colors.black87
                          : Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getAchievements() {
    final userAchievements = _currentUser?.achievements ?? [];
    final lessonsCompleted = _currentUser?.lessonsCompleted ?? 0;
    final streak = _currentUser?.practiceStreak ?? 0;
    final allTimeMinutes = _currentUser?.allTimePracticeMinutes ?? 0;

    return [
      {
        'title': 'First Steps',
        'icon': Icons.baby_changing_station,
        'color': Color(0xFFB13BFF),
        'unlocked': userAchievements.contains('first_steps'),
        'id': 'first_steps',
      },
      {
        'title': '7 Day Streak',
        'icon': Icons.local_fire_department,
        'color': Color(0xFFFF3F33),
        'unlocked': userAchievements.contains('7_day_streak'),
        'id': '7_day_streak',
      },
      {
        'title': 'Dedicated',
        'icon': Icons.star,
        'color': Color(0xFF4DA8DA),
        'unlocked': userAchievements.contains('dedicated'),
        'id': 'dedicated',
      },
      {
        'title': 'Persistent',
        'icon': Icons.trending_up,
        'color': Color(0xFF16C47F),
        'unlocked': userAchievements.contains('persistent'),
        'id': 'persistent',
      },
      {
        'title': 'Expert Level',
        'icon': Icons.military_tech,
        'color': Color(0xFFFCF259),
        'unlocked': userAchievements.contains('expert_level'),
        'id': 'expert_level',
      },
      {
        'title': 'Master',
        'icon': Icons.emoji_events,
        'color': Color(0xFFFF2929),
        'unlocked': userAchievements.contains('master'),
        'id': 'master',
      },
    ];
  }

  Color _getLevelColor(String level) {
    switch (level) {
      case 'Beginner':
        return Color(0xFF4CAF50);
      case 'Novice':
        return Color(0xFF2196F3);
      case 'Intermediate':
        return Color(0xFF9C27B0);
      case 'Advanced':
        return Color(0xFFFF9800);
      case 'Expert':
        return Color(0xFFFF6B35);
      default:
        return Color(0xFF4CAF50);
    }
  }

  IconData _getLevelIcon(String level) {
    switch (level) {
      case 'Beginner':
        return Icons.school;
      case 'Novice':
        return Icons.trending_up;
      case 'Intermediate':
        return Icons.star_half;
      case 'Advanced':
        return Icons.star;
      case 'Expert':
        return Icons.emoji_events;
      default:
        return Icons.school;
    }
  }
}