// lib/screens/practice_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:swar_music_app/screens/tanpura_player_screen.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'lesson_details_screen.dart';

class PracticeTab extends StatefulWidget {
  @override
  _PracticeTabState createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab> {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  Map<String, dynamic>? _practiceProgress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _authService.getUserDocument(user.uid);
        final progress = await _authService.getDailyPracticeProgress(user.uid);

        if (userDoc != null && mounted) {
          setState(() {
            _currentUser = UserModel.fromFirestore(userDoc);
            _practiceProgress = progress;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
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
      onRefresh: _loadUserData,
      color: Color(0xFFFF6B35),
      child: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDailyGoalCard(),
            SizedBox(height: 25),
            _buildQuickPracticeSection(),
            SizedBox(height: 25),
            _buildPracticeModesSection(),
            SizedBox(height: 25),
            _buildPracticeToolsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyGoalCard() {
    final dailyMinutes = _practiceProgress?['dailyMinutes'] ?? 0;
    final goalMinutes = _practiceProgress?['goalMinutes'] ?? 30;
    final progressPercentage = _practiceProgress?['progressPercentage'] ?? 0.0;
    final goalAchieved = _practiceProgress?['goalAchieved'] ?? false;

    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: goalAchieved
              ? [Color(0xFFFF5722), Color(0xFFFF8A65)]
              : [Color(0xFFFF6B35), Color(0xFFFF8A50)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (goalAchieved ? Color(0xFF4CAF50) : Color(0xFFFF6B35)).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 6),
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
                    goalAchieved ? 'Goal Achieved! 🎉' : 'Today\'s Practice Goal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${dailyMinutes}m / ${goalMinutes}m',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                width: 60,
                height: 60,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        value: (progressPercentage / 100).clamp(0.0, 1.0),
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    Text(
                      '${progressPercentage.round()}%',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          LinearProgressIndicator(
            value: (progressPercentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.3),
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                '${_currentUser?.practiceStreak ?? 0} day streak',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 14,
                ),
              ),
              Spacer(),
              if (!goalAchieved)
                Text(
                  '${goalMinutes - dailyMinutes}m remaining',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPracticeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Practice',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildQuickPracticeCard(
                'Voice Warm-up',
                'Sa Re Ga Ma',
                Icons.mic,
                Color(0xFF4CAF50),
                    () => _navigateToLessonDetails('VoiceWarmup', 'Voice Warm-up'),
              ),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildQuickPracticeCard(
                'Breathing',
                'Pranayama',
                Icons.air,
                Color(0xFF2196F3),
                    () => _navigateToLessonDetails('Breathing', 'Breathing Exercises'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickPracticeCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 25),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPracticeModesSection() {
    final practiceModes = [
      {
        'title': 'Guided Practice',
        'description': 'Follow along with structured lessons',
        'icon': Icons.school,
        'color': Color(0xFF4CAF50),
        'route': () => _navigateToLessonDetails('BasicAlankar', 'Basic Alankars'),
      },
      {
        'title': 'Free Practice',
        'description': 'Practice with Tanpura accompaniment',
        'icon': Icons.music_note,
        'color': Color(0xFF2196F3),
        'route': () => _showFreePracticeDialog(),
      },
      {
        'title': 'Skill Builder',
        'description': 'Focus on specific techniques',
        'icon': Icons.trending_up,
        'color': Color(0xFF9C27B0),
        'route': () => _navigateToLessonDetails('IntermediateAlankar', 'Skill Builders'),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Modes',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Column(
          children: practiceModes.map((mode) {
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: mode['route'] as VoidCallback,
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
                          color: (mode['color'] as Color).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          mode['icon'] as IconData,
                          color: mode['color'] as Color,
                          size: 25,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode['title'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              mode['description'] as String,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.grey[400],
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPracticeToolsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Tools',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildToolCard('Tanpura', Icons.radio, Color(0xFF4CAF50)),
            ),
            SizedBox(width: 15),
            Expanded(
              child: _buildToolCard('Metronome', Icons.av_timer, Color(0xFF2196F3)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == 'Tanpura') {
          // Navigate to the tanpura player screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TanpuraPlayerScreen()),
          );
        } else if (title == 'Metronome') {
          // Show "coming soon" snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title tool coming soon!'),
              backgroundColor: color,
            ),
          );
        }
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLessonDetails(String genre, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LessonDetailsScreen(
          genre: genre,
          title: title,
        ),
      ),
    );
  }

  void _showFreePracticeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Free Practice'),
        content: Text('Choose your practice setup:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to free practice mode
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Start Practice', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}