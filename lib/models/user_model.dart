import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final bool isPremium;
  final DateTime createdAt;
  final int practiceStreak;
  final int totalPracticeMinutes; // Daily practice minutes (resets daily)
  final int allTimePracticeMinutes; // All-time total practice minutes
  final int lessonsCompleted;
  final List<String> favoriteRagas;
  final int dailyGoalMinutes;
  final String reminderTime;
  final bool notificationsEnabled;
  final DateTime? lastActiveDate;
  final DateTime? lastPracticeResetDate;
  final bool profileCompleted;
  final List<String> achievements; // Achievement IDs
  final Map<String, int> weeklyProgress; // Weekly progress tracking

  // Subscription fields
  final SubscriptionStatus subscriptionStatus;
  final String? subscriptionId;
  final String? purchaseToken;
  final DateTime? subscriptionStartDate;
  final DateTime? subscriptionEndDate;
  final String? subscriptionProductId;
  final bool autoRenewing;
  final DateTime? lastSubscriptionCheck;
  final int freePracticeMinutesUsed; // Track free minutes used today

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.isPremium,
    required this.createdAt,
    required this.practiceStreak,
    required this.totalPracticeMinutes,
    required this.allTimePracticeMinutes,
    required this.lessonsCompleted,
    required this.favoriteRagas,
    required this.dailyGoalMinutes,
    required this.reminderTime,
    required this.notificationsEnabled,
    this.lastActiveDate,
    this.lastPracticeResetDate,
    required this.profileCompleted,
    required this.achievements,
    required this.weeklyProgress,
    this.subscriptionStatus = SubscriptionStatus.none,
    this.subscriptionId,
    this.purchaseToken,
    this.subscriptionStartDate,
    this.subscriptionEndDate,
    this.subscriptionProductId,
    this.autoRenewing = false,
    this.lastSubscriptionCheck,
    this.freePracticeMinutesUsed = 0,
  });

  // Create UserModel from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? 'Music Lover',
      photoURL: data['photoURL'],
      isPremium: data['isPremium'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      practiceStreak: data['practiceStreak'] ?? 0,
      totalPracticeMinutes: data['totalPracticeMinutes'] ?? 0,
      allTimePracticeMinutes: data['allTimePracticeMinutes'] ?? 0,
      lessonsCompleted: data['lessonsCompleted'] ?? 0,
      favoriteRagas: List<String>.from(data['favoriteRagas'] ?? []),
      dailyGoalMinutes: data['dailyGoalMinutes'] ?? 30,
      reminderTime: data['reminderTime'] ?? '18:00',
      notificationsEnabled: data['notificationsEnabled'] ?? true,
      lastActiveDate: (data['lastActiveDate'] as Timestamp?)?.toDate(),
      lastPracticeResetDate: (data['lastPracticeResetDate'] as Timestamp?)?.toDate(),
      profileCompleted: data['profileCompleted'] ?? false,
      achievements: List<String>.from(data['achievements'] ?? []),
      weeklyProgress: Map<String, int>.from(data['weeklyProgress'] ?? {}),
      subscriptionStatus: SubscriptionStatus.fromString(data['subscriptionStatus'] ?? 'none'),
      subscriptionId: data['subscriptionId'],
      purchaseToken: data['purchaseToken'],
      subscriptionStartDate: (data['subscriptionStartDate'] as Timestamp?)?.toDate(),
      subscriptionEndDate: (data['subscriptionEndDate'] as Timestamp?)?.toDate(),
      subscriptionProductId: data['subscriptionProductId'],
      autoRenewing: data['autoRenewing'] ?? false,
      lastSubscriptionCheck: (data['lastSubscriptionCheck'] as Timestamp?)?.toDate(),
      freePracticeMinutesUsed: data['freePracticeMinutesUsed'] ?? 0,
    );
  }

  // Convert UserModel to Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'isPremium': isPremium,
      'createdAt': Timestamp.fromDate(createdAt),
      'practiceStreak': practiceStreak,
      'totalPracticeMinutes': totalPracticeMinutes,
      'allTimePracticeMinutes': allTimePracticeMinutes,
      'lessonsCompleted': lessonsCompleted,
      'favoriteRagas': favoriteRagas,
      'dailyGoalMinutes': dailyGoalMinutes,
      'reminderTime': reminderTime,
      'notificationsEnabled': notificationsEnabled,
      'lastActiveDate': lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
      'lastPracticeResetDate': lastPracticeResetDate != null ?
      Timestamp.fromDate(lastPracticeResetDate!) : null,
      'profileCompleted': profileCompleted,
      'achievements': achievements,
      'weeklyProgress': weeklyProgress,
      'subscriptionStatus': subscriptionStatus.toString(),
      'subscriptionId': subscriptionId,
      'purchaseToken': purchaseToken,
      'subscriptionStartDate': subscriptionStartDate != null ? Timestamp.fromDate(subscriptionStartDate!) : null,
      'subscriptionEndDate': subscriptionEndDate != null ? Timestamp.fromDate(subscriptionEndDate!) : null,
      'subscriptionProductId': subscriptionProductId,
      'autoRenewing': autoRenewing,
      'lastSubscriptionCheck': lastSubscriptionCheck != null ? Timestamp.fromDate(lastSubscriptionCheck!) : null,
      'freePracticeMinutesUsed': freePracticeMinutesUsed,
    };
  }

  // Create a copy with updated fields
  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    bool? isPremium,
    DateTime? createdAt,
    int? practiceStreak,
    int? totalPracticeMinutes,
    int? allTimePracticeMinutes,
    int? lessonsCompleted,
    List<String>? favoriteRagas,
    int? dailyGoalMinutes,
    String? reminderTime,
    bool? notificationsEnabled,
    DateTime? lastActiveDate,
    DateTime? lastPracticeResetDate,
    bool? profileCompleted,
    List<String>? achievements,
    Map<String, int>? weeklyProgress,
    SubscriptionStatus? subscriptionStatus,
    String? subscriptionId,
    String? purchaseToken,
    DateTime? subscriptionStartDate,
    DateTime? subscriptionEndDate,
    String? subscriptionProductId,
    bool? autoRenewing,
    DateTime? lastSubscriptionCheck,
    int? freePracticeMinutesUsed,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      isPremium: isPremium ?? this.isPremium,
      createdAt: createdAt ?? this.createdAt,
      practiceStreak: practiceStreak ?? this.practiceStreak,
      totalPracticeMinutes: totalPracticeMinutes ?? this.totalPracticeMinutes,
      allTimePracticeMinutes: allTimePracticeMinutes ?? this.allTimePracticeMinutes,
      lessonsCompleted: lessonsCompleted ?? this.lessonsCompleted,
      favoriteRagas: favoriteRagas ?? this.favoriteRagas,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      reminderTime: reminderTime ?? this.reminderTime,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      lastActiveDate: lastActiveDate ?? this.lastActiveDate,
      lastPracticeResetDate: lastPracticeResetDate ?? this.lastPracticeResetDate,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      achievements: achievements ?? this.achievements,
      weeklyProgress: weeklyProgress ?? this.weeklyProgress,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionId: subscriptionId ?? this.subscriptionId,
      purchaseToken: purchaseToken ?? this.purchaseToken,
      subscriptionStartDate: subscriptionStartDate ?? this.subscriptionStartDate,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      subscriptionProductId: subscriptionProductId ?? this.subscriptionProductId,
      autoRenewing: autoRenewing ?? this.autoRenewing,
      lastSubscriptionCheck: lastSubscriptionCheck ?? this.lastSubscriptionCheck,
      freePracticeMinutesUsed: freePracticeMinutesUsed ?? this.freePracticeMinutesUsed,
    );
  }

  // Check if user has active subscription
  bool get hasActiveSubscription {
    if (subscriptionStatus == SubscriptionStatus.active && subscriptionEndDate != null) {
      return DateTime.now().isBefore(subscriptionEndDate!);
    }
    return false;
  }

  // Check if user can practice (either has subscription or has free minutes left)
  bool get canPractice {
    return hasActiveSubscription || freePracticeMinutesUsed < 15;
  }

  // Get remaining free minutes
  int get remainingFreeMinutes {
    if (hasActiveSubscription) return -1; // Unlimited for premium users
    return (15 - freePracticeMinutesUsed).clamp(0, 15);
  }

  // Check if subscription is expiring soon (within 3 days)
  bool get isSubscriptionExpiringSoon {
    if (subscriptionStatus == SubscriptionStatus.active && subscriptionEndDate != null) {
      final daysUntilExpiry = subscriptionEndDate!.difference(DateTime.now()).inDays;
      return daysUntilExpiry <= 3 && daysUntilExpiry >= 0;
    }
    return false;
  }

  // Get subscription display status
  String get subscriptionDisplayStatus {
    switch (subscriptionStatus) {
      case SubscriptionStatus.active:
        if (hasActiveSubscription) {
          return autoRenewing ? 'Active (Auto-renewing)' : 'Active';
        } else {
          return 'Expired';
        }
      case SubscriptionStatus.expired:
        return 'Expired';
      case SubscriptionStatus.cancelled:
        return 'Cancelled';
      case SubscriptionStatus.pending:
        return 'Pending';
      case SubscriptionStatus.none:
      default:
        return 'Free Plan';
    }
  }

  // Get subscription end date formatted
  String get formattedSubscriptionEndDate {
    if (subscriptionEndDate != null) {
      return '${subscriptionEndDate!.day}/${subscriptionEndDate!.month}/${subscriptionEndDate!.year}';
    }
    return 'N/A';
  }

  // Calculate daily practice progress
  double get dailyProgress {
    if (dailyGoalMinutes <= 0) return 0.0;
    return (totalPracticeMinutes / dailyGoalMinutes).clamp(0.0, 1.0);
  }

  // Check if daily goal is achieved
  bool get isDailyGoalAchieved {
    return totalPracticeMinutes >= dailyGoalMinutes;
  }

  // Get remaining minutes to reach daily goal
  int get remainingMinutesToGoal {
    if (isDailyGoalAchieved) return 0;
    return dailyGoalMinutes - totalPracticeMinutes;
  }

  // Get practice level based on all-time total minutes
  String get practiceLevel {
    if (allTimePracticeMinutes < 60) return 'Beginner';
    if (allTimePracticeMinutes < 300) return 'Novice';
    if (allTimePracticeMinutes < 600) return 'Intermediate';
    if (allTimePracticeMinutes < 1200) return 'Advanced';
    return 'Expert';
  }

  // Get practice level progress (0.0 to 1.0)
  double get practiceLevelProgress {
    if (allTimePracticeMinutes < 60) return allTimePracticeMinutes / 60;
    if (allTimePracticeMinutes < 300) return (allTimePracticeMinutes - 60) / 240;
    if (allTimePracticeMinutes < 600) return (allTimePracticeMinutes - 300) / 300;
    if (allTimePracticeMinutes < 1200) return (allTimePracticeMinutes - 600) / 600;
    return 1.0; // Expert level
  }

  // Get next level info
  Map<String, dynamic> get nextLevelInfo {
    if (allTimePracticeMinutes < 60) {
      return {
        'nextLevel': 'Novice',
        'minutesNeeded': 60 - allTimePracticeMinutes,
        'totalRequired': 60,
      };
    }
    if (allTimePracticeMinutes < 300) {
      return {
        'nextLevel': 'Intermediate',
        'minutesNeeded': 300 - allTimePracticeMinutes,
        'totalRequired': 300,
      };
    }
    if (allTimePracticeMinutes < 600) {
      return {
        'nextLevel': 'Advanced',
        'minutesNeeded': 600 - allTimePracticeMinutes,
        'totalRequired': 600,
      };
    }
    if (allTimePracticeMinutes < 1200) {
      return {
        'nextLevel': 'Expert',
        'minutesNeeded': 1200 - allTimePracticeMinutes,
        'totalRequired': 1200,
      };
    }
    return {
      'nextLevel': 'Master',
      'minutesNeeded': 0,
      'totalRequired': 1200,
    };
  }

  // Check if user has specific achievement
  bool hasAchievement(String achievementId) {
    return achievements.contains(achievementId);
  }

  // Get streak description
  String get streakDescription {
    if (practiceStreak == 0) return 'Start your practice streak!';
    if (practiceStreak == 1) return '1 day streak!';
    if (practiceStreak < 7) return '$practiceStreak days streak!';
    if (practiceStreak < 30) return '$practiceStreak days streak! 🔥';
    return '$practiceStreak days streak! 🚀🔥';
  }

  // Get motivational message based on daily progress
  String get dailyMotivationalMessage {
    final progress = dailyProgress;
    if (progress >= 1.0) {
      return 'Daily goal achieved! 🎉 You\'re on fire!';
    } else if (progress >= 0.8) {
      return 'Almost there! Just $remainingMinutesToGoal more minutes!';
    } else if (progress >= 0.5) {
      return 'Great progress! Keep going!';
    } else if (progress > 0.0) {
      return 'Good start! Let\'s practice more today!';
    } else {
      return 'Ready to start practicing today?';
    }
  }

  // Get practice consistency over the week (requires additional data)
  String get consistencyLevel {
    // This would need weekly practice data to calculate accurately
    // For now, base it on current streak
    if (practiceStreak >= 7) return 'Excellent';
    if (practiceStreak >= 5) return 'Great';
    if (practiceStreak >= 3) return 'Good';
    if (practiceStreak >= 1) return 'Building';
    return 'Starting';
  }

  // Check if user needs to be reset for new day
  bool get needsDailyReset {
    if (lastPracticeResetDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastReset = lastPracticeResetDate!;
    final lastResetDay = DateTime(lastReset.year, lastReset.month, lastReset.day);
    return today.isAfter(lastResetDay);
  }

  // Get formatted practice time
  String get formattedDailyTime {
    final hours = totalPracticeMinutes ~/ 60;
    final minutes = totalPracticeMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedAllTimeTotal {
    final hours = allTimePracticeMinutes ~/ 60;
    final minutes = allTimePracticeMinutes % 60;
    if (hours > 24) {
      final days = hours ~/ 24;
      final remainingHours = hours % 24;
      return '${days}d ${remainingHours}h';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Get today's progress for weekly chart
  int getTodayProgress() {
    return totalPracticeMinutes;
  }

  // Get progress for specific day from weekly data
  int getProgressForDay(String dayKey) {
    return weeklyProgress[dayKey] ?? 0;
  }

  // Check if today's goal is achieved
  bool get isTodayGoalAchieved {
    return totalPracticeMinutes >= dailyGoalMinutes;
  }

  // Get progress percentage for specific day
  double getProgressPercentageForDay(String dayKey) {
    final minutes = dayKey == _getTodayKey() ? totalPracticeMinutes : (weeklyProgress[dayKey] ?? 0);
    if (dailyGoalMinutes <= 0) return 0.0;
    return (minutes / dailyGoalMinutes).clamp(0.0, 1.0);
  }

  // Helper to get today's key
  String _getTodayKey() {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[now.weekday - 1];
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, practiceStreak: $practiceStreak, dailyMinutes: $totalPracticeMinutes, allTimeMinutes: $allTimePracticeMinutes, subscriptionStatus: $subscriptionStatus, hasActiveSubscription: $hasActiveSubscription)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.uid == uid;
  }

  @override
  int get hashCode => uid.hashCode;
}

// Subscription Status Enum
enum SubscriptionStatus {
  none,
  active,
  expired,
  cancelled,
  pending;

  static SubscriptionStatus fromString(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'expired':
        return SubscriptionStatus.expired;
      case 'cancelled':
        return SubscriptionStatus.cancelled;
      case 'pending':
        return SubscriptionStatus.pending;
      case 'none':
      default:
        return SubscriptionStatus.none;
    }
  }

  @override
  String toString() {
    return name;
  }
}