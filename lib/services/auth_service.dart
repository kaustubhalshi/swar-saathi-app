import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'revenuecat_service.dart'; // Add this import

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final RevenueCatService _revenueCatService = RevenueCatService(); // Add this

  // Get current user
  Future<User?> getCurrentUser() async {
    return _auth.currentUser;
  }

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        // Create or update user document in Firestore
        await _createOrUpdateUserDocument(user, userCredential.additionalUserInfo?.isNewUser ?? false);

        // Initialize RevenueCat for the user
        try {
          await _revenueCatService.initialize();
          await _revenueCatService.loginUser(user.uid);
        } catch (e) {
          print('RevenueCat initialization failed: $e');
          // Don't fail the login if RevenueCat fails
        }

        // Setup notifications for existing users
        if (!(userCredential.additionalUserInfo?.isNewUser ?? false)) {
          await setupDailyNotifications(user.uid);
        }
      }

      return user;
    } catch (e) {
      print('Error signing in with Google: $e');
      return null;
    }
  }

  // Create or update user document in Firestore
  Future<void> _createOrUpdateUserDocument(User user, bool isNewUser) async {
    try {
      final userDocRef = _firestore.collection('users').doc(user.uid);

      if (isNewUser) {
        // Initialize weekly progress for current week
        final now = DateTime.now();
        final weekStart = _getWeekStart(now);
        final weeklyProgress = <String, int>{};
        for (int i = 0; i < 7; i++) {
          final day = weekStart.add(Duration(days: i));
          final dayKey = _getDayKey(day);
          weeklyProgress[dayKey] = 0;
        }

        // Create new user document with default values
        final userData = {
          'uid': user.uid,
          'email': user.email ?? '',
          'displayName': user.displayName ?? 'Music Lover',
          'photoURL': user.photoURL,
          'isPremium': false,
          'createdAt': FieldValue.serverTimestamp(),
          'practiceStreak': 0,
          'totalPracticeMinutes': 0, // Daily practice minutes
          'allTimePracticeMinutes': 0, // All-time total
          'lessonsCompleted': 0,
          'favoriteRagas': <String>[],
          'dailyGoalMinutes': 30, // Default 30 minutes daily goal
          'reminderTime': '18:00', // Default 6 PM reminder
          'notificationsEnabled': true,
          'lastActiveDate': FieldValue.serverTimestamp(),
          'lastPracticeResetDate': FieldValue.serverTimestamp(), // Track when daily practice was last reset
          'profileCompleted': false,
          'achievements': <String>[], // Initialize empty achievements array
          'weeklyProgress': weeklyProgress, // Initialize weekly progress
          'currentWeekStart': Timestamp.fromDate(weekStart), // Track current week
          'subscriptionStatus': 'none',
          'subscriptionId': null,
          'purchaseToken': null,
          'subscriptionStartDate': null,
          'subscriptionEndDate': null,
          'subscriptionProductId': null,
          'autoRenewing': false,
          'lastSubscriptionCheck': null,
          'freePracticeMinutesUsed': 0,
        };

        await userDocRef.set(userData);

        // Setup notifications for new users (enabled by default)
        await setupDailyNotifications(user.uid);
      } else {
        // Check if document exists first
        final docSnapshot = await userDocRef.get();
        if (docSnapshot.exists) {
          // Update existing user document with latest info
          final updateData = {
            'email': user.email ?? '',
            'displayName': user.displayName ?? 'Music Lover',
            'photoURL': user.photoURL,
            'lastActiveDate': FieldValue.serverTimestamp(),
          };
          await userDocRef.update(updateData);

          // Check if daily practice needs to be reset
          await _checkAndResetDailyPractice(user.uid);

          // Ensure weekly progress is initialized
          await getWeeklyPracticeSummary(user.uid);
        } else {
          // Document doesn't exist, create it even though isNewUser is false
          // Initialize weekly progress for current week
          final now = DateTime.now();
          final weekStart = _getWeekStart(now);
          final weeklyProgress = <String, int>{};
          for (int i = 0; i < 7; i++) {
            final day = weekStart.add(Duration(days: i));
            final dayKey = _getDayKey(day);
            weeklyProgress[dayKey] = 0;
          }

          final userData = {
            'uid': user.uid,
            'email': user.email ?? '',
            'displayName': user.displayName ?? 'Music Lover',
            'photoURL': user.photoURL,
            'isPremium': false,
            'createdAt': FieldValue.serverTimestamp(),
            'practiceStreak': 0,
            'totalPracticeMinutes': 0, // Daily practice minutes
            'allTimePracticeMinutes': 0, // All-time total
            'lessonsCompleted': 0,
            'favoriteRagas': <String>[],
            'dailyGoalMinutes': 30,
            'reminderTime': '18:00',
            'notificationsEnabled': true,
            'lastActiveDate': FieldValue.serverTimestamp(),
            'lastPracticeResetDate': FieldValue.serverTimestamp(),
            'profileCompleted': false,
            'achievements': <String>[], // Initialize empty achievements array
            'weeklyProgress': weeklyProgress, // Initialize weekly progress
            'currentWeekStart': Timestamp.fromDate(weekStart), // Track current week
            'subscriptionStatus': 'none',
            'subscriptionId': null,
            'purchaseToken': null,
            'subscriptionStartDate': null,
            'subscriptionEndDate': null,
            'subscriptionProductId': null,
            'autoRenewing': false,
            'lastSubscriptionCheck': null,
            'freePracticeMinutesUsed': 0,
          };

          await userDocRef.set(userData);

          // Setup notifications for fallback user creation
          await setupDailyNotifications(user.uid);
        }
      }
    } catch (e) {
      print('Error creating/updating user document: $e');
      // Even if Firestore fails, we don't want to fail the login
      // The user document can be created later
    }
  }

  // Enhanced achievement checking with notifications
  Future<void> checkAndUpdateAchievements(String uid) async {
    try {
      final userDoc = await getUserDocument(uid);
      if (userDoc == null || !userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final currentAchievements = List<String>.from(data['achievements'] ?? []);
      final lessonsCompleted = data['lessonsCompleted'] ?? 0;
      final practiceStreak = data['practiceStreak'] ?? 0;
      final allTimePracticeMinutes = data['allTimePracticeMinutes'] ?? 0;

      List<String> newAchievements = [];
      Map<String, String> achievementDetails = {};

      // Achievement 1: First Steps (complete first lesson)
      if (lessonsCompleted >= 1 && !currentAchievements.contains('first_steps')) {
        newAchievements.add('first_steps');
        achievementDetails['first_steps'] = 'Complete your first lesson';
      }

      // Achievement 2: 7 Day Streak
      if (practiceStreak >= 7 && !currentAchievements.contains('7_day_streak')) {
        newAchievements.add('7_day_streak');
        achievementDetails['7_day_streak'] = 'Practice for 7 consecutive days';
      }

      // Achievement 3: Dedicated (complete 10 lessons)
      if (lessonsCompleted >= 10 && !currentAchievements.contains('dedicated')) {
        newAchievements.add('dedicated');
        achievementDetails['dedicated'] = 'Complete 10 lessons';
      }

      // Achievement 4: Persistent (600+ minutes of practice)
      if (allTimePracticeMinutes >= 600 && !currentAchievements.contains('persistent')) {
        newAchievements.add('persistent');
        achievementDetails['persistent'] = 'Practice for 10+ hours total';
      }

      // Achievement 5: Expert Level (complete 70 lessons)
      if (lessonsCompleted >= 70 && !currentAchievements.contains('expert_level')) {
        newAchievements.add('expert_level');
        achievementDetails['expert_level'] = 'Complete 70 lessons';
      }

      // Achievement 6: Master (complete all lessons)
      // First, get total lessons count
      final totalLessons = await getTotalLessonsCount();
      if (lessonsCompleted >= totalLessons && totalLessons > 0 && !currentAchievements.contains('master')) {
        newAchievements.add('master');
        achievementDetails['master'] = 'Complete all available lessons';
      }

      // Update achievements if there are new ones
      if (newAchievements.isNotEmpty) {
        final updatedAchievements = [...currentAchievements, ...newAchievements];
        await _firestore.collection('users').doc(uid).update({
          'achievements': updatedAchievements,
        });

        // Show notification for each new achievement
        for (final achievement in newAchievements) {
          final description = achievementDetails[achievement] ?? 'New achievement unlocked!';
          await _notificationService.showAchievementNotification(
            achievementTitle: _getAchievementTitle(achievement),
            achievementDescription: description,
            uid: uid, // Pass uid for storage
            achievementId: achievement,
          );
        }
      }
    } catch (e) {
      print('Error checking achievements: $e');
    }
  }

  // Helper method to get user-friendly achievement titles
  String _getAchievementTitle(String achievementId) {
    switch (achievementId) {
      case 'first_steps':
        return 'First Steps';
      case '7_day_streak':
        return '7 Day Streak';
      case 'dedicated':
        return 'Dedicated Learner';
      case 'persistent':
        return 'Persistent Practitioner';
      case 'expert_level':
        return 'Expert Level';
      case 'master':
        return 'Master Musician';
      default:
        return 'Achievement';
    }
  }

  // Get total lessons count from lessons collection
  Future<int> getTotalLessonsCount() async {
    try {
      final lessonsSnapshot = await _firestore.collection('lessons').get();
      return lessonsSnapshot.docs.length;
    } catch (e) {
      print('Error getting total lessons count: $e');
      return 0;
    }
  }

  // Enhanced daily practice reset with proper weekly progress tracking
  Future<void> _checkAndResetDailyPractice(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final lastResetDate = data['lastPracticeResetDate'] as Timestamp?;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (lastResetDate != null) {
          final lastReset = lastResetDate.toDate();
          final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

          // If it's a new day, save current progress to weekly chart and reset daily practice
          if (today.isAfter(lastResetDay)) {
            print('🔄 New day detected - saving yesterday\'s progress and resetting');

            // First, save yesterday's final progress to weekly chart
            final totalPracticeMinutes = data['totalPracticeMinutes'] ?? 0;
            await _saveYesterdayProgressAndReset(uid, lastResetDay, totalPracticeMinutes);
          }
        } else {
          // First time user - initialize reset date
          await userDocRef.update({
            'lastPracticeResetDate': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error checking daily practice reset: $e');
    }
  }

  // Save yesterday's progress and reset for new day
  Future<void> _saveYesterdayProgressAndReset(String uid, DateTime yesterdayDate, int yesterdayMinutes) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final data = userDoc.data() as Map<String, dynamic>;
      final currentWeekStart = data['currentWeekStart'] as Timestamp?;
      final now = DateTime.now();
      final thisWeekStart = _getWeekStart(now);

      // Get current weekly progress
      Map<String, int> weeklyProgress = Map<String, int>.from(data['weeklyProgress'] ?? {});

      // Check if we need to reset for a new week
      if (currentWeekStart == null ||
          _getWeekStart(currentWeekStart.toDate()).isBefore(thisWeekStart)) {
        print('📅 New week detected - resetting weekly progress');

        // Initialize new week with all days set to 0
        weeklyProgress = {};
        for (int i = 0; i < 7; i++) {
          final day = thisWeekStart.add(Duration(days: i));
          final dayKey = _getDayKey(day);
          weeklyProgress[dayKey] = 0;
        }
      } else {
        // Same week - save yesterday's progress if it was in current week
        final yesterdayWeekStart = _getWeekStart(yesterdayDate);
        if (yesterdayWeekStart.isAtSameMomentAs(thisWeekStart)) {
          final yesterdayKey = _getDayKey(yesterdayDate);
          weeklyProgress[yesterdayKey] = yesterdayMinutes;
          print('💾 Saved yesterday ($yesterdayKey) progress: $yesterdayMinutes minutes');
        }
      }

      // Reset daily practice and update weekly progress
      await userDocRef.update({
        'totalPracticeMinutes': 0,
        'freePracticeMinutesUsed': 0,
        'lastPracticeResetDate': FieldValue.serverTimestamp(),
        'weeklyProgress': weeklyProgress,
        'currentWeekStart': Timestamp.fromDate(thisWeekStart),
      });

      print('✅ Daily reset completed');
    } catch (e) {
      print('❌ Error saving yesterday\'s progress and resetting: $e');
    }
  }

  Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      final docSnapshot = await _firestore.collection('users').doc(uid).get();
      return docSnapshot.exists ? docSnapshot : null;
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }

  // Update user document
  Future<bool> updateUserDocument(String uid, Map<String, dynamic> data) async {
    try {
      await _firestore.collection('users').doc(uid).update(data);
      return true;
    } catch (e) {
      print('Error updating user document: $e');
      return false;
    }
  }

  // Enhanced version of checkAndResetDailyPracticeWithFreeMinutes
  Future<void> checkAndResetDailyPracticeWithFreeMinutes(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final lastResetDate = data['lastPracticeResetDate'] as Timestamp?;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (lastResetDate != null) {
          final lastReset = lastResetDate.toDate();
          final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);

          // If it's a new day, save current progress to weekly chart and reset daily practice
          if (today.isAfter(lastResetDay)) {
            print('🔄 New day detected - resetting daily practice and free minutes');

            // Save yesterday's progress and reset
            final totalPracticeMinutes = data['totalPracticeMinutes'] ?? 0;
            await _saveYesterdayProgressAndReset(uid, lastResetDay, totalPracticeMinutes);

            print('✅ Daily reset completed - free minutes restored');
          } else {
            print('📅 Same day - no reset needed');
          }
        } else {
          // First time user - initialize reset date and ensure free minutes are set
          print('🆕 First time user - initializing daily reset');
          await userDocRef.update({
            'lastPracticeResetDate': FieldValue.serverTimestamp(),
            'freePracticeMinutesUsed': 0,
          });
        }
      }
    } catch (e) {
      print('❌ Error checking daily practice reset with free minutes: $e');
    }
  }

  // Enhanced practice streak update with proper date handling
  Future<bool> updatePracticeStreak(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final lastActiveDate = data['lastActiveDate'] as Timestamp?;
        final currentStreak = data['practiceStreak'] as int? ?? 0;

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        int newStreak;
        bool shouldUpdate = false;

        if (lastActiveDate != null) {
          final lastActive = lastActiveDate.toDate();
          final lastActiveDay = DateTime(lastActive.year, lastActive.month, lastActive.day);
          final daysDifference = today.difference(lastActiveDay).inDays;

          print('🔍 Streak Debug:');
          print('Today: $today');
          print('Last Active Day: $lastActiveDay');
          print('Days Difference: $daysDifference');
          print('Current Streak: $currentStreak');

          if (daysDifference == 0) {
            // Same day - don't change streak, but ensure it's at least 1 if this is first practice
            newStreak = currentStreak == 0 ? 1 : currentStreak;
            shouldUpdate = currentStreak == 0; // Only update if streak was 0
          } else if (daysDifference == 1) {
            // Next day - increment streak
            newStreak = currentStreak + 1;
            shouldUpdate = true;

            // Show streak milestone notifications
            if (newStreak == 7 || newStreak == 30 || newStreak == 100 ||
                (newStreak % 7 == 0 && newStreak > 7)) {
              await _notificationService.showStreakNotification(newStreak, uid: uid);
            }
          } else if (daysDifference > 1) {
            // Missed days - reset streak to 1 (current practice counts)
            newStreak = 1;
            shouldUpdate = true;
            print('🔄 Streak reset due to missed days');
          } else {
            // This shouldn't happen (negative days), but handle it
            newStreak = currentStreak;
            shouldUpdate = false;
          }
        } else {
          // First time practicing
          newStreak = 1;
          shouldUpdate = true;
          print('🎉 First time practicing - setting streak to 1');
        }

        // Only update if there's a change
        if (shouldUpdate) {
          print('✅ Updating streak from $currentStreak to $newStreak');

          await userDocRef.update({
            'practiceStreak': newStreak,
            'lastActiveDate': FieldValue.serverTimestamp(),
          });

          // Check achievements after updating streak
          await checkAndUpdateAchievements(uid);
        } else {
          print('⏭️ No streak update needed');
        }

        return true;
      }
      return false;
    } catch (e) {
      print('Error updating practice streak: $e');
      return false;
    }
  }

  // Enhanced add practice minutes with RevenueCat integration
  Future<bool> addPracticeMinutes(String uid, int minutes) async {
    try {
      // Use RevenueCat service for practice minutes logic (handles premium vs free)
      final success = await _revenueCatService.addPracticeMinutes(uid, minutes);

      if (success) {
        // Update today's progress in weekly chart immediately
        final userDocRef = _firestore.collection('users').doc(uid);
        final userDoc = await userDocRef.get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final currentDailyMinutes = userData['totalPracticeMinutes'] ?? 0;
          await _updateTodayProgressInWeeklyChart(uid, currentDailyMinutes);
        }

        // Get progress for goal completion check
        final progress = await getDailyPracticeProgress(uid);
        final currentDailyMinutes = progress?['dailyMinutes'] ?? 0;
        final goalMinutes = progress?['goalMinutes'] ?? 30;

        // Check for goal completion notification
        final wasGoalNotReached = (currentDailyMinutes - minutes) < goalMinutes;
        final isGoalNowReached = currentDailyMinutes >= goalMinutes;

        if (wasGoalNotReached && isGoalNowReached) {
          await _notificationService.showGoalCompletionNotification(
            uid: uid,
            goalMinutes: goalMinutes,
            completedMinutes: currentDailyMinutes,
          );
        }

        // IMPORTANT: Update streak AFTER adding practice minutes
        await updatePracticeStreak(uid);

        // Check achievements after adding practice minutes
        await checkAndUpdateAchievements(uid);
      }

      return success;
    } catch (e) {
      print('Error adding practice minutes: $e');
      return false;
    }
  }

  // Add method to check if user can practice (using RevenueCat)
  Future<bool> canUserPractice(String uid) async {
    try {
      return await _revenueCatService.canUserPractice(uid);
    } catch (e) {
      print('Error checking if user can practice: $e');
      return false;
    }
  }

  // Add method to get remaining free minutes (using RevenueCat)
  Future<int> getRemainingFreeMinutes(String uid) async {
    try {
      return await _revenueCatService.getRemainingFreeMinutes(uid);
    } catch (e) {
      print('Error getting remaining free minutes: $e');
      return 0;
    }
  }

  // Add method to check practice permission (using RevenueCat)
  Future<Map<String, dynamic>> checkPracticePermission(String uid) async {
    try {
      return await _revenueCatService.checkPracticePermission(uid);
    } catch (e) {
      print('Error checking practice permission: $e');
      return {
        'canPractice': false,
        'isPremium': false,
        'message': 'Error checking permissions',
      };
    }
  }

  // Update today's progress in weekly chart (called in real-time)
  Future<void> _updateTodayProgressInWeeklyChart(String uid, int todayMinutes) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      final userDoc = await userDocRef.get();

      if (!userDoc.exists) return;

      final userData = userDoc.data() as Map<String, dynamic>;
      Map<String, int> weeklyProgress = Map<String, int>.from(userData['weeklyProgress'] ?? {});

      final today = DateTime.now();
      final todayKey = _getDayKey(DateTime(today.year, today.month, today.day));

      // Update today's progress in real-time
      weeklyProgress[todayKey] = todayMinutes;

      // Save back to Firestore
      await userDocRef.update({
        'weeklyProgress': weeklyProgress,
      });

      print('📊 Updated today ($todayKey) progress: $todayMinutes minutes');
    } catch (e) {
      print('Error updating today\'s progress in weekly chart: $e');
    }
  }

  // Reset daily practice minutes (called at midnight or when user opens app on new day)
  Future<bool> resetDailyPracticeMinutes(String uid) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.update({
        'totalPracticeMinutes': 0,
        'lastPracticeResetDate': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error resetting daily practice minutes: $e');
      return false;
    }
  }

  // Get daily practice progress
  Future<Map<String, dynamic>?> getDailyPracticeProgress(String uid) async {
    try {
      final userDoc = await getUserDocument(uid);
      if (userDoc != null && userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final dailyMinutes = data['totalPracticeMinutes'] ?? 0;
        final goalMinutes = data['dailyGoalMinutes'] ?? 30;
        final allTimeMinutes = data['allTimePracticeMinutes'] ?? 0;
        final streak = data['practiceStreak'] ?? 0;

        return {
          'dailyMinutes': dailyMinutes,
          'goalMinutes': goalMinutes,
          'allTimeMinutes': allTimeMinutes,
          'streak': streak,
          'progressPercentage': (dailyMinutes / goalMinutes * 100).clamp(0, 100),
          'goalAchieved': dailyMinutes >= goalMinutes,
        };
      }
      return null;
    } catch (e) {
      print('Error getting daily practice progress: $e');
      return null;
    }
  }

  // Complete a lesson
  Future<bool> completeLesson(String uid, String lessonId) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.update({
        'lessonsCompleted': FieldValue.increment(1),
        'lastActiveDate': FieldValue.serverTimestamp(),
      });

      // Check achievements after completing lesson
      await checkAndUpdateAchievements(uid);
      return true;
    } catch (e) {
      print('Error completing lesson: $e');
      return false;
    }
  }

  // Add favorite raga
  Future<bool> addFavoriteRaga(String uid, String raga) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.update({
        'favoriteRagas': FieldValue.arrayUnion([raga]),
      });
      return true;
    } catch (e) {
      print('Error adding favorite raga: $e');
      return false;
    }
  }

  // Remove favorite raga
  Future<bool> removeFavoriteRaga(String uid, String raga) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);
      await userDocRef.update({
        'favoriteRagas': FieldValue.arrayRemove([raga]),
      });
      return true;
    } catch (e) {
      print('Error removing favorite raga: $e');
      return false;
    }
  }

  // Enhanced user preferences update with notification management
  Future<bool> updateUserPreferences(String uid, {
    int? dailyGoalMinutes,
    String? reminderTime,
    bool? notificationsEnabled,
  }) async {
    try {
      final updateData = <String, dynamic>{};

      if (dailyGoalMinutes != null) {
        updateData['dailyGoalMinutes'] = dailyGoalMinutes;
      }
      if (reminderTime != null) {
        updateData['reminderTime'] = reminderTime;
      }
      if (notificationsEnabled != null) {
        updateData['notificationsEnabled'] = notificationsEnabled;
      }

      if (updateData.isNotEmpty) {
        await _firestore.collection('users').doc(uid).update(updateData);

        // Update notifications if settings changed
        if (reminderTime != null || notificationsEnabled != null) {
          await setupDailyNotifications(uid);
        }
      }

      return true;
    } catch (e) {
      print('Error updating user preferences: $e');
      return false;
    }
  }

  // Setup daily notifications when user enables them
  Future<bool> setupDailyNotifications(String uid) async {
    try {
      final userDoc = await getUserDocument(uid);
      if (userDoc == null || !userDoc.exists) return false;

      final data = userDoc.data() as Map<String, dynamic>;
      final notificationsEnabled = data['notificationsEnabled'] ?? false;
      final reminderTime = data['reminderTime'] ?? '18:00';

      if (notificationsEnabled) {
        final parts = reminderTime.split(':');
        final hour = int.tryParse(parts[0]) ?? 18;
        final minute = int.tryParse(parts[1]) ?? 0;

        await _notificationService.scheduleDailyNotification(
          hour: hour,
          minute: minute,
        );
        return true;
      } else {
        await _notificationService.cancelAllNotifications();
        return true;
      }
    } catch (e) {
      print('Error setting up daily notifications: $e');
      return false;
    }
  }

  // Record practice session data
  Future<bool> recordPracticeSession(String uid, {
    required String lessonId,
    required String lessonTitle,
    required int practiceMinutes,
    required double averageAccuracy,
    required int totalNotes,
    required int correctNotes,
    required int finalScore,
  }) async {
    try {
      final userDocRef = _firestore.collection('users').doc(uid);

      // Add to practice sessions subcollection
      await userDocRef.collection('practiceSessions').add({
        'lessonId': lessonId,
        'lessonTitle': lessonTitle,
        'practiceMinutes': practiceMinutes,
        'averageAccuracy': averageAccuracy,
        'totalNotes': totalNotes,
        'correctNotes': correctNotes,
        'finalScore': finalScore,
        'sessionDate': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update user's practice minutes
      await addPracticeMinutes(uid, practiceMinutes);

      return true;
    } catch (e) {
      print('Error recording practice session: $e');
      return false;
    }
  }

  // Get practice history
  Future<List<Map<String, dynamic>>> getPracticeHistory(String uid, {int limit = 10}) async {
    try {
      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('practiceSessions')
          .orderBy('sessionDate', descending: true)
          .limit(limit)
          .get();

      return sessionsSnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      print('Error getting practice history: $e');
      return [];
    }
  }

  // Get practice stats for a specific time period
  Future<Map<String, dynamic>> getPracticeStats(String uid, {int days = 7}) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: days));

      final sessionsSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('practiceSessions')
          .where('sessionDate', isGreaterThan: Timestamp.fromDate(startDate))
          .get();

      if (sessionsSnapshot.docs.isEmpty) {
        return {
          'totalSessions': 0,
          'totalMinutes': 0,
          'averageAccuracy': 0.0,
          'averageScore': 0.0,
          'daysActive': 0,
        };
      }

      int totalSessions = sessionsSnapshot.docs.length;
      int totalMinutes = 0;
      double totalAccuracy = 0.0;
      double totalScore = 0.0;
      Set<String> activeDays = {};

      for (final doc in sessionsSnapshot.docs) {
        final data = doc.data();
        totalMinutes += (data['practiceMinutes'] ?? 0) as int;
        totalAccuracy += (data['averageAccuracy'] ?? 0.0) as double;
        totalScore += (data['finalScore'] ?? 0.0) as double;

        final sessionDate = (data['sessionDate'] as Timestamp).toDate();
        final dayKey = '${sessionDate.year}-${sessionDate.month}-${sessionDate.day}';
        activeDays.add(dayKey);
      }

      return {
        'totalSessions': totalSessions,
        'totalMinutes': totalMinutes,
        'averageAccuracy': totalAccuracy / totalSessions,
        'averageScore': totalScore / totalSessions,
        'daysActive': activeDays.length,
      };
    } catch (e) {
      print('Error getting practice stats: $e');
      return {
        'totalSessions': 0,
        'totalMinutes': 0,
        'averageAccuracy': 0.0,
        'averageScore': 0.0,
        'daysActive': 0,
      };
    }
  }

  // Sign out with RevenueCat logout
  Future<void> signOut() async {
    try {
      // Logout from RevenueCat first
      await _revenueCatService.logoutUser();

      // Then logout from Google and Firebase
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Stream of user document changes
  Stream<DocumentSnapshot> getUserDocumentStream(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }

  // Check if user has reached daily goal
  Future<bool> hasReachedDailyGoal(String uid) async {
    try {
      final progress = await getDailyPracticeProgress(uid);
      return progress?['goalAchieved'] ?? false;
    } catch (e) {
      print('Error checking daily goal: $e');
      return false;
    }
  }

  // Enhanced weekly practice summary with proper initialization
  Future<Map<String, int>> getWeeklyPracticeSummary(String uid) async {
    try {
      final userDoc = await getUserDocument(uid);
      if (userDoc == null || !userDoc.exists) return {};

      final userData = userDoc.data() as Map<String, dynamic>;
      final now = DateTime.now();
      final currentWeekStart = _getWeekStart(now);
      final storedWeekStart = userData['currentWeekStart'] as Timestamp?;

      // Check if it's a new week or first time
      if (storedWeekStart == null ||
          _getWeekStart(storedWeekStart.toDate()).isBefore(currentWeekStart)) {

        print('🔄 Initializing new week progress');

        // Initialize new week with current day having today's progress
        final newWeeklyProgress = <String, int>{};
        final todayMinutes = userData['totalPracticeMinutes'] ?? 0;

        for (int i = 0; i < 7; i++) {
          final day = currentWeekStart.add(Duration(days: i));
          final dayKey = _getDayKey(day);

          // Set today's progress, others to 0
          final today = DateTime(now.year, now.month, now.day);
          final currentDay = DateTime(day.year, day.month, day.day);
          newWeeklyProgress[dayKey] = currentDay.isAtSameMomentAs(today) ? todayMinutes : 0;
        }

        // Update in Firestore
        await _firestore.collection('users').doc(uid).update({
          'weeklyProgress': newWeeklyProgress,
          'currentWeekStart': Timestamp.fromDate(currentWeekStart),
        });

        return newWeeklyProgress;
      }

      // Return existing weekly progress for current week
      final weeklyProgress = Map<String, int>.from(userData['weeklyProgress'] ?? {});

      // Ensure today's progress is up to date
      final today = DateTime(now.year, now.month, now.day);
      final todayKey = _getDayKey(today);
      final todayMinutes = userData['totalPracticeMinutes'] ?? 0;

      if (weeklyProgress[todayKey] != todayMinutes) {
        weeklyProgress[todayKey] = todayMinutes;

        // Update in Firestore
        await _firestore.collection('users').doc(uid).update({
          'weeklyProgress': weeklyProgress,
        });
      }

      return weeklyProgress;
    } catch (e) {
      print('Error getting weekly practice summary: $e');
      return {};
    }
  }

  // Public method to manually check and reset daily practice
  Future<void> checkAndResetDailyPractice(String uid) async {
    await _checkAndResetDailyPractice(uid);
  }

  // Get week start (Monday)
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    return DateTime(date.year, date.month, date.day).subtract(Duration(days: weekday - 1));
  }

  // Get day key for weekly progress mapping
  String _getDayKey(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[date.weekday - 1];
  }

  // Dispose RevenueCat service
  void dispose() {
    _revenueCatService.dispose();
  }
}