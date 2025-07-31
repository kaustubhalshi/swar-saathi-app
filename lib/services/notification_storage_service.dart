// lib/services/notification_storage_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType {
  dailyReminder,
  goalCompleted,
  achievement,
  streakMilestone,
  general,
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
    this.metadata,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: NotificationType.values.firstWhere(
            (e) => e.name == data['type'],
        orElse: () => NotificationType.general,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'metadata': metadata,
    };
  }

  AppNotification copyWith({
    String? id,
    String? title,
    String? body,
    NotificationType? type,
    DateTime? createdAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
    );
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String get typeDisplayName {
    switch (type) {
      case NotificationType.dailyReminder:
        return 'Daily Reminder';
      case NotificationType.goalCompleted:
        return 'Goal Completed';
      case NotificationType.achievement:
        return 'Achievement';
      case NotificationType.streakMilestone:
        return 'Streak Milestone';
      case NotificationType.general:
        return 'General';
    }
  }
}

class NotificationStorageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Store a notification in Firestore
  Future<String?> storeNotification({
    required String uid,
    required String title,
    required String body,
    required NotificationType type,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = AppNotification(
        id: '', // Will be set by Firestore
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        isRead: false,
        metadata: metadata,
      );

      final docRef = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(notification.toFirestore());

      print('📱 Notification stored with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error storing notification: $e');
      return null;
    }
  }

  /// Get all notifications for a user
  Future<List<AppNotification>> getNotifications(String uid, {
    int limit = 50,
    bool unreadOnly = false,
  }) async {
    try {
      Query query = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      query = query.limit(limit);

      final snapshot = await query.get();
      return snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
    } catch (e) {
      print('❌ Error getting notifications: $e');
      return [];
    }
  }

  /// Get notifications stream for real-time updates
  Stream<List<AppNotification>> getNotificationsStream(String uid, {
    int limit = 50,
    bool unreadOnly = false,
  }) {
    try {
      Query query = _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .orderBy('createdAt', descending: true);

      if (unreadOnly) {
        query = query.where('isRead', isEqualTo: false);
      }

      query = query.limit(limit);

      return query.snapshots().map((snapshot) =>
          snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
    } catch (e) {
      print('❌ Error getting notifications stream: $e');
      return Stream.value([]);
    }
  }

  /// Mark notification as read
  Future<bool> markAsRead(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});

      print('✅ Notification $notificationId marked as read');
      return true;
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead(String uid) async {
    try {
      final batch = _firestore.batch();
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      print('✅ All notifications marked as read');
      return true;
    } catch (e) {
      print('❌ Error marking all notifications as read: $e');
      return false;
    }
  }

  /// Delete a notification
  Future<bool> deleteNotification(String uid, String notificationId) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .doc(notificationId)
          .delete();

      print('✅ Notification $notificationId deleted');
      return true;
    } catch (e) {
      print('❌ Error deleting notification: $e');
      return false;
    }
  }

  /// Delete old notifications (older than specified days)
  Future<bool> deleteOldNotifications(String uid, {int daysOld = 30}) async {
    try {
      final cutoffDate = DateTime.now().subtract(Duration(days: daysOld));
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('✅ Deleted ${snapshot.docs.length} old notifications');
      return true;
    } catch (e) {
      print('❌ Error deleting old notifications: $e');
      return false;
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount(String uid) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }

  /// Get unread count stream
  Stream<int> getUnreadCountStream(String uid) {
    try {
      return _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      print('❌ Error getting unread count stream: $e');
      return Stream.value(0);
    }
  }

  /// Store achievement notification with metadata
  Future<String?> storeAchievementNotification({
    required String uid,
    required String achievementId,
    required String achievementTitle,
    required String description,
  }) async {
    return await storeNotification(
      uid: uid,
      title: '🏆 Achievement Unlocked!',
      body: '$achievementTitle - $description',
      type: NotificationType.achievement,
      metadata: {
        'achievementId': achievementId,
        'achievementTitle': achievementTitle,
      },
    );
  }

  /// Store streak milestone notification
  Future<String?> storeStreakNotification({
    required String uid,
    required int streakDays,
  }) async {
    String title = '🔥 Streak Milestone!';
    String body = '';

    if (streakDays == 7) {
      body = 'Amazing! You\'ve reached a 7-day practice streak!';
    } else if (streakDays == 30) {
      body = 'Incredible! 30 days of consistent practice!';
    } else if (streakDays == 100) {
      body = 'Legendary! 100 days of dedication to music!';
    } else if (streakDays % 7 == 0) {
      body = 'Great job! $streakDays days of consistent practice!';
    }

    if (body.isNotEmpty) {
      return await storeNotification(
        uid: uid,
        title: title,
        body: body,
        type: NotificationType.streakMilestone,
        metadata: {
          'streakDays': streakDays,
        },
      );
    }
    return null;
  }

  /// Store goal completion notification
  Future<String?> storeGoalCompletionNotification({
    required String uid,
    required int minutesCompleted,
    required int goalMinutes,
  }) async {
    return await storeNotification(
      uid: uid,
      title: '🎯 Daily Goal Achieved!',
      body: 'Congratulations! You\'ve completed your daily practice goal of $goalMinutes minutes.',
      type: NotificationType.goalCompleted,
      metadata: {
        'minutesCompleted': minutesCompleted,
        'goalMinutes': goalMinutes,
      },
    );
  }
}