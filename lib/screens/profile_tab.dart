// lib/screens/profile_tab.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/revenuecat_service.dart'; // Updated import
import '../services/notification_service.dart';
import '../services/notification_storage_service.dart';
import '../screens/notification_screen.dart';
import '../screens/subscription_screen.dart';
import '../models/user_model.dart';

class ProfileTab extends StatefulWidget {
  @override
  _ProfileTabState createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final AuthService _authService = AuthService();
  final RevenueCatService _revenueCatService = RevenueCatService(); // Updated service
  final NotificationService _notificationService = NotificationService();
  UserModel? _currentUser;
  Map<String, dynamic>? _subscriptionInfo;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _initializeRevenueCatService(); // Updated method name
  }

  Future<void> _initializeRevenueCatService() async {
    try {
      await _revenueCatService.initialize();
    } catch (e) {
      print('Error initializing RevenueCat service: $e');
    }
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await _authService.getUserDocument(user.uid);
        if (userDoc != null && mounted) {
          final subscriptionInfo = await _revenueCatService.getSubscriptionInfo(user.uid); // Updated service call
          setState(() {
            _currentUser = UserModel.fromFirestore(userDoc);
            _subscriptionInfo = subscriptionInfo;
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
          children: [
            _buildProfileHeader(),
            SizedBox(height: 30),
            _buildStatsOverview(),
            SizedBox(height: 25),
            _buildSubscriptionSection(), // Updated subscription section
            SizedBox(height: 25),
            _buildPreferencesSection(),
            SizedBox(height: 25),
            _buildAccountSection(),
            SizedBox(height: 25),
            _buildAppSection(),
            SizedBox(height: 30),
            _buildSignOutButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final user = FirebaseAuth.instance.currentUser;

    return Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFF6B35).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              image: user?.photoURL != null
                  ? DecorationImage(
                image: NetworkImage(user!.photoURL!),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: user?.photoURL == null
                ? Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            )
                : null,
          ),
          SizedBox(height: 16),
          Text(
            _currentUser?.displayName ?? 'Music Lover',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 4),
          Text(
            user?.email ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.military_tech, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      _currentUser?.practiceLevel ?? 'Beginner',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      '${_currentUser?.practiceStreak ?? 0} days',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    return Container(
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
          Text(
            'Practice Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Practice',
                  _currentUser?.formattedAllTimeTotal ?? '0m',
                  Icons.access_time,
                  Color(0xFF4CAF50),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Lessons Done',
                  '${_currentUser?.lessonsCompleted ?? 0}',
                  Icons.school,
                  Color(0xFF2196F3),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Daily Goal',
                  '${_currentUser?.dailyGoalMinutes ?? 30}m',
                  Icons.flag,
                  Color(0xFF9C27B0),
                ),
              ),
              Expanded(
                child: _buildStatItem(
                  'Favorite Ragas',
                  '${_currentUser?.favoriteRagas.length ?? 0}',
                  Icons.favorite,
                  Color(0xFFFF9800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // Updated subscription section with RevenueCat
  Widget _buildSubscriptionSection() {
    final hasActiveSubscription = _subscriptionInfo?['hasActiveSubscription'] ?? false;
    final subscriptionStatus = _subscriptionInfo?['status'] ?? SubscriptionStatus.none;
    final remainingMinutes = _subscriptionInfo?['remainingFreeMinutes'] ?? 15;
    final usedMinutes = _subscriptionInfo?['freePracticeMinutesUsed'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Subscription',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (!hasActiveSubscription)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'UPGRADE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: 15),

        // Subscription Status Card
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SubscriptionScreen(),
              ),
            ).then((_) => _loadUserData()); // Refresh data when returning
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasActiveSubscription ? Color(0xFF4CAF50) : Color(0xFFFF6B35),
                width: 1,
              ),
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
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (hasActiveSubscription ? Color(0xFF4CAF50) : Color(0xFFFF6B35)).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        hasActiveSubscription ? Icons.diamond : Icons.access_time,
                        color: hasActiveSubscription ? Color(0xFF4CAF50) : Color(0xFFFF6B35),
                        size: 20,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                hasActiveSubscription ? 'Premium Active' : 'Free Plan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 8),
                              if (hasActiveSubscription)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4CAF50).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'PRO',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF4CAF50),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: 2),
                          Text(
                            hasActiveSubscription
                                ? 'Unlimited practice access'
                                : '$remainingMinutes free minutes left today',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
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

                if (!hasActiveSubscription) ...[
                  SizedBox(height: 12),
                  // Free usage progress bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Today\'s usage',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '$usedMinutes / 15 min',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: usedMinutes / 15,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      remainingMinutes > 5 ? Color(0xFF4CAF50) :
                      remainingMinutes > 0 ? Colors.orange : Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    remainingMinutes > 0
                        ? 'Practice time resets every day at midnight'
                        : 'Free time used up! Upgrade for unlimited access.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],

                if (hasActiveSubscription && _subscriptionInfo?['endDate'] != null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF4CAF50).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule, size: 14, color: Color(0xFF4CAF50)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _subscriptionInfo?['autoRenewing'] == true
                                ? 'Renews on ${_formatDate(_subscriptionInfo!['endDate'])}'
                                : 'Expires on ${_formatDate(_subscriptionInfo!['endDate'])}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF4CAF50),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_subscriptionInfo?['autoRenewing'] == true)
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Color(0xFF4CAF50).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'AUTO',
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4CAF50),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        SizedBox(height: 12),

        // Action buttons
        Row(
          children: [
            if (!hasActiveSubscription) ...[
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubscriptionScreen(),
                      ),
                    ).then((_) => _loadUserData()); // Refresh data when returning
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF6B35),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.diamond, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SubscriptionScreen(),
                      ),
                    ).then((_) => _loadUserData()); // Refresh data when returning
                  },
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Color(0xFF4CAF50)),
                    padding: EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Manage Subscription',
                        style: TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildPreferencesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Preferences',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        _buildSettingItem(
          'Daily Goal',
          '${_currentUser?.dailyGoalMinutes ?? 30} minutes',
          Icons.flag,
              () => _showDailyGoalDialog(),
        ),
        _buildSettingItem(
          'Practice Reminder',
          _currentUser?.reminderTime ?? '18:00',
          Icons.notifications,
              () => _showReminderTimeDialog(),
        ),
        _buildNotificationSettingItem(),
      ],
    );
  }

  // Fixed notification setting item with proper state management
  Widget _buildNotificationSettingItem() {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
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
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFFFF6B35).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.notifications_active, color: Color(0xFFFF6B35), size: 20),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Daily practice reminders',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: _currentUser?.notificationsEnabled ?? true,
              onChanged: (value) => _toggleNotifications(value),
              activeColor: Color(0xFFFF6B35),
              activeTrackColor: Color(0xFFFF6B35).withOpacity(0.3),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: Colors.grey.withOpacity(0.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        _buildSettingItem(
          'Edit Profile',
          'Update your information',
          Icons.person_outline,
              () => _showEditProfileDialog(),
        ),
        _buildSettingItem(
          'Favorite Ragas',
          'Manage your preferences',
          Icons.favorite_outline,
              () => _showFavoriteRagasDialog(),
        ),
        // _buildSettingItem(
        //   'Practice History',
        //   'View all sessions',
        //   Icons.history,
        //       () => _showPracticeHistory(),
        // ),
      ],
    );
  }

  Widget _buildAppSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'App',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 15),
        _buildSettingItem(
          'About Swar Saathi',
          'Version 1.0.11',
          Icons.info_outline,
              () => _showAboutDialog(),
        ),
        _buildSettingItem(
          'Help & Support',
          'Get assistance',
          Icons.help_outline,
              () => _showSupportDialog(),
        ),
        _buildSettingItem(
          'Privacy Policy',
          'Review our policies',
          Icons.privacy_tip_outlined,
              () => _openPrivacyPolicy(),
        ),
      ],
    );
  }

  Widget _buildSettingItem(String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
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
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFFFF6B35).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Color(0xFFFF6B35), size: 20),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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
  }

  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _showSignOutDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[400],
          padding: EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // Dialog methods
  void _showDailyGoalDialog() {
    int currentGoal = _currentUser?.dailyGoalMinutes ?? 30;
    int newGoal = currentGoal;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Daily Practice Goal'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Set your daily practice goal in minutes'),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      if (newGoal > 15) {
                        setDialogState(() => newGoal -= 15);
                      }
                    },
                    icon: Icon(Icons.remove),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF6B35).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$newGoal min',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      if (newGoal < 120) {
                        setDialogState(() => newGoal += 15);
                      }
                    },
                    icon: Icon(Icons.add),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _authService.updateUserPreferences(
                    user.uid,
                    dailyGoalMinutes: newGoal,
                  );
                  _loadUserData();
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showReminderTimeDialog() {
    TimeOfDay currentTime = TimeOfDay.now();
    try {
      final timeString = _currentUser?.reminderTime ?? '18:00';
      final parts = timeString.split(':');
      currentTime = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    } catch (e) {
      currentTime = TimeOfDay(hour: 18, minute: 0);
    }

    showTimePicker(
      context: context,
      initialTime: currentTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: Color(0xFFFF6B35)),
          ),
          child: child!,
        );
      },
    ).then((time) async {
      if (time != null) {
        final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _authService.updateUserPreferences(
            user.uid,
            reminderTime: timeString,
          );

          // Update notification if notifications are enabled
          if (_currentUser?.notificationsEnabled == true) {
            await _notificationService.scheduleDailyNotification(
              hour: time.hour,
              minute: time.minute,
            );
          }

          _loadUserData();
        }
      }
    });
  }

  // Fixed toggle notifications method with proper state management
  void _toggleNotifications(bool value) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show loading indicator
    setState(() {
      _isLoading = true;
    });

    try {
      if (value) {
        // Request permission first
        final hasPermission = await _notificationService.requestPermission();

        if (hasPermission) {
          // Update user preferences
          await _authService.updateUserPreferences(
            user.uid,
            notificationsEnabled: true,
          );

          // Schedule notification with current reminder time
          final reminderTime = _currentUser?.reminderTime ?? '18:00';
          final parts = reminderTime.split(':');
          final hour = int.tryParse(parts[0]) ?? 18;
          final minute = int.tryParse(parts[1]) ?? 0;

          await _notificationService.scheduleDailyNotification(
            hour: hour,
            minute: minute,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Practice reminders enabled at $reminderTime'),
              backgroundColor: Color(0xFF4CAF50),
            ),
          );
        } else {
          // Permission denied, keep notifications disabled
          await _authService.updateUserPreferences(
            user.uid,
            notificationsEnabled: false,
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification permission is required to enable reminders'),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: 'Settings',
                textColor: Colors.white,
                onPressed: () {
                  // Open app settings - this would require another package like app_settings
                },
              ),
            ),
          );
        }
      } else {
        // Disable notifications
        await _authService.updateUserPreferences(
          user.uid,
          notificationsEnabled: false,
        );

        await _notificationService.cancelAllNotifications();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Practice reminders disabled'),
            backgroundColor: Colors.grey,
          ),
        );
      }
    } catch (e) {
      print('Error toggling notifications: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update notification settings'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Reload user data to reflect changes
      await _loadUserData();
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: _currentUser?.displayName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFFF6B35)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null && nameController.text.isNotEmpty) {
                await _authService.updateUserDocument(user.uid, {
                  'displayName': nameController.text.trim(),
                });
                _loadUserData();
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showFavoriteRagasDialog() {
    final availableRagas = ['Yaman', 'Bhairav', 'Malkauns', 'Kafi', 'Bhupali', 'Darbari', 'Bageshri', 'Jaunpuri'];
    final favoriteRagas = List<String>.from(_currentUser?.favoriteRagas ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Favorite Ragas'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select your favorite ragas to get personalized recommendations'),
                SizedBox(height: 16),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: availableRagas.length,
                    itemBuilder: (context, index) {
                      final raga = availableRagas[index];
                      final isSelected = favoriteRagas.contains(raga);

                      return CheckboxListTile(
                        title: Text(raga),
                        value: isSelected,
                        activeColor: Color(0xFFFF6B35),
                        onChanged: (value) {
                          setDialogState(() {
                            if (value == true) {
                              favoriteRagas.add(raga);
                            } else {
                              favoriteRagas.remove(raga);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await _authService.updateUserDocument(user.uid, {
                    'favoriteRagas': favoriteRagas,
                  });
                  _loadUserData();
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
              child: Text('Save', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('About Swar Saathi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Swar Saathi - Your Musical Companion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Version: 1.0.0'),
            SizedBox(height: 16),
            Text(
              'Learn Indian classical music with AI-powered voice analysis and personalized feedback.',
            ),
            SizedBox(height: 16),
            Text(
              'Developed with ❤️ for music enthusiasts',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Help & Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.email, color: Color(0xFFFF6B35)),
              title: Text('Email Support'),
              subtitle: Text('swarsaathi40@gmail.com'),
              onTap: () {
                // Launch email
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(Icons.feedback, color: Color(0xFFFF6B35)),
              title: Text('Send Feedback'),
              subtitle: Text('Help us improve'),
              onTap: () {
                // Show feedback form
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF6B35)),
            child: Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Updated privacy policy method to open URL in browser
  void _openPrivacyPolicy() async {
    const url = 'https://sites.google.com/view/swarsathi/privacy-policy';

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open privacy policy. Please visit: $url'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error opening privacy policy: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open privacy policy. Please visit: $url'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _authService.signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[400]),
            child: Text('Sign Out', style: TextStyle(color: Colors.white)),
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