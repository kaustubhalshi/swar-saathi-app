// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:swar_music_app/screens/tanpura_player_screen.dart';
import '../services/auth_service.dart';
import '../services/notification_storage_service.dart';
import '../models/user_model.dart';
import '../screens/notification_screen.dart';
import 'lesson_details_screen.dart';
import 'practice_tab.dart';
import 'progress_tab.dart';
import 'profile_tab.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final AuthService _authService = AuthService();

  final List<Widget> _screens = [
    LearningTab(),
    PracticeTab(),
    ProgressTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeHomeScreen();
  }

  // Initialize home screen with necessary checks
  Future<void> _initializeHomeScreen() async {
    await _checkDailyReset();
    await _requestNotificationPermissionOnce();
  }

  // Check if it's a new day and reset daily practice if needed
  Future<void> _checkDailyReset() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // This will check if it's after midnight and reset totalPracticeMinutes if needed
        await _authService.checkAndResetDailyPractice(user.uid);
      }
    } catch (e) {
      print('❌ Error checking daily reset: $e');
    }
  }

  Future<void> _requestNotificationPermissionOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasAskedPermission = prefs.getBool(
          'has_asked_notification_permission') ?? false;

      // Only ask for permission if we haven't asked before
      if (!hasAskedPermission) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Request notification permission
          final status = await Permission.notification.request();

          // Mark that we've asked for permission
          await prefs.setBool('has_asked_notification_permission', true);

          // Update user's notification preference based on permission status
          bool notificationsEnabled = status == PermissionStatus.granted;

          await _authService.updateUserPreferences(
            user.uid,
            notificationsEnabled: notificationsEnabled,
          );

          print('📱 Notification permission status: $status');
          print('📱 Notifications enabled: $notificationsEnabled');
        }
      }
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true, // ✅ To allow content under nav bar
      backgroundColor: Color(0xFFF7F3E9), // ✅ Background under status & nav bars
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'स्वर साथी',
          style: TextStyle(
            color: Color(0xFFFF6B35),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: NotificationStorageService().getUnreadCountStream(
              FirebaseAuth.instance.currentUser?.uid ?? '',
            ),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(
                        Icons.notifications_outlined, color: Color(0xFFFF6B35)),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => NotificationScreen()),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea( // ✅ This is the correct place to apply SafeArea
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: SafeArea( // ✅ Keep for nav bar padding on gesture devices
        child: Container(
          margin: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: Offset(0, 5),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.transparent,
              elevation: 0,
              selectedItemColor: Color(0xFFFF6B35),
              unselectedItemColor: Colors.grey[500],
              selectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 11,
              ),
              items: [
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 0
                          ? Color(0xFFFF6B35).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ImageIcon(
                      AssetImage('assets/icons/learn_icon.png'),
                      size: 24,
                    ),
                  ),
                  label: 'Learn',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 1
                          ? Color(0xFFFF6B35).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.play_circle_outline,
                      size: 24,
                    ),
                  ),
                  label: 'Practice',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 2
                          ? Color(0xFFFF6B35).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      size: 24,
                    ),
                  ),
                  label: 'Progress',
                ),
                BottomNavigationBarItem(
                  icon: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedIndex == 3
                          ? Color(0xFFFF6B35).withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.person_outline,
                      size: 24,
                    ),
                  ),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LearningTab extends StatefulWidget {
  @override
  _LearningTabState createState() => _LearningTabState();
}

class _LearningTabState extends State<LearningTab> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  UserModel? _currentUser;
  Map<String, dynamic>? _practiceProgress;
  bool _isLoading = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          _animationController.forward();
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
            _buildWelcomeCard(),
            SizedBox(height: 20),
            _buildSectionTitle('Alankars'),
            SizedBox(height: 15),
            _buildAlankarCards(context),
            SizedBox(height: 25),
            _buildSectionTitle('Explore Ragas'),
            SizedBox(height: 15),
            _buildRagaGrid(),
            SizedBox(height: 25),
            _buildSectionTitle('Quick Practice'),
            SizedBox(height: 15),
            _buildQuickPracticeCards(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard() {
    final dailyMinutes = _practiceProgress?['dailyMinutes'] ?? 0;
    final goalMinutes = _practiceProgress?['goalMinutes'] ?? 30;
    final streak = _currentUser?.practiceStreak ?? 0;
    final goalAchieved = _practiceProgress?['goalAchieved'] ?? false;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _animationController.value),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: goalAchieved
                      ? [Color(0xFF2196F3), Color(0xFF64B5F6)]
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
                  Text(
                    _getGreeting(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    goalAchieved
                        ? 'Goal achieved! 🎉'
                        : 'Ready to practice today?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 15),
                  Row(
                    children: [
                      Icon(Icons.access_time, color: Colors.white, size: 16),
                      SizedBox(width: 8),
                      Text(
                        '$dailyMinutes/$goalMinutes min today',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      Spacer(),
                      Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                    ],
                  ),
                  if (!goalAchieved) ...[
                    SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: goalMinutes > 0 ? (dailyMinutes / goalMinutes).clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.white.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning!';
    if (hour < 17) return 'Good Afternoon!';
    return 'Good Evening!';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildAlankarCards(BuildContext context) {
    final alankars = [
      {
        'title': 'Basic Alankars',
        'description': 'Foundation exercises',
        'genre': 'BasicAlankar',
        'color': Color(0xFF4CAF50),
        'icon': Icons.looks_one,
      },
      // {
      //   'title': 'Intermediate Alankars',
      //   'description': 'Progressive patterns',
      //   'genre': 'IntermediateAlankar',
      //   'color': Color(0xFF2196F3),
      //   'icon': Icons.looks_two,
      // },
      {
        'title': 'Advanced Alankars',
        'description': 'Complex variations',
        'genre': 'AdvancedAlankar',
        'color': Color(0xFF9C27B0),
        'icon': Icons.looks_two,
      },
    ];

    return Column(
      children: alankars.map((alankar) {
        return Container(
          margin: EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonDetailsScreen(
                    genre: alankar['genre'] as String,
                    title: alankar['title'] as String,
                  ),
                ),
              );
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
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: (alankar['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      alankar['icon'] as IconData,
                      color: alankar['color'] as Color,
                      size: 30,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alankar['title'] as String,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          alankar['description'] as String,
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
    );
  }

  Widget _buildRagaGrid() {
    final ragas = [
      {'name': 'Yaman', 'color': Color(0xFF4CAF50)},
      {'name': 'Bhairav', 'color': Color(0xFF2196F3)},
      {'name': 'Malkauns', 'color': Color(0xFF9C27B0)},
      {'name': 'Kafi', 'color': Color(0xFFFF9800)},
    ];

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: ragas.length,
        padding: EdgeInsets.symmetric(horizontal: 4),
        itemBuilder: (context, index) {
          final raga = ragas[index];
          return Container(
            margin: EdgeInsets.only(right: 10),
            width: 140,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LessonDetailsScreen(
                      genre: 'Raga${raga['name']}',
                      title: 'Raga ${raga['name']}',
                    ),
                  ),
                );
              },
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (raga['color'] as Color).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.music_note,
                        color: raga['color'] as Color,
                        size: 20,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      raga['name'] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickPracticeCards() {
    return Row(
      children: [
        Expanded(
          child: _buildPracticeCard('Tanpura', Icons.radio, Color(0xFF4CAF50)),
        ),
        SizedBox(width: 15),
        Expanded(
          child: _buildPracticeCard('Metronome', Icons.av_timer, Color(0xFF2196F3)),
        ),
      ],
    );
  }

  Widget _buildPracticeCard(String title, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        if (title == 'Tanpura') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TanpuraPlayerScreen()),
          );
        } else if (title == 'Metronome') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$title tool coming soon!'),
              backgroundColor: color,
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
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
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
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
}