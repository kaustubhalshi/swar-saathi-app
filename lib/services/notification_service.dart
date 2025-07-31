// lib/services/notification_service.dart
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'notification_storage_service.dart'; // Add this import

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  final NotificationStorageService _storageService = NotificationStorageService(); // Add this

  static const int _practiceReminderNotificationId = 1001;

  /// Initialize the notification service
  Future<void> initialize() async {
    // Initialize timezone data
    tz.initializeTimeZones();

    // Initialize notification settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize notification settings for iOS
    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    print('🔔 Notification service initialized');
  }

  /// Handle notification tap events
  void _onNotificationTapped(NotificationResponse notificationResponse) {
    print('🔔 Notification tapped: ${notificationResponse.payload}');
    // You can navigate to specific screens or perform actions here
    // For example, navigate to practice screen when notification is tapped
  }

  /// Request notification permissions
  Future<bool> requestPermission() async {
    try {
      // For Android 13+ (API level 33+), we need to request notification permission
      bool? granted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      // For iOS, request permissions
      bool? iosGranted = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      final isGranted = granted ?? iosGranted ?? true;
      print('🔔 Notification permission granted: $isGranted');

      // Also request exact alarm permission for Android 12+
      await requestExactAlarmPermission();

      return isGranted;
    } catch (e) {
      print('❌ Error requesting notification permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission for Android 12+
  Future<bool> requestExactAlarmPermission() async {
    try {
      final androidImplementation = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidImplementation != null) {
        // Check if exact alarms are already permitted
        final bool? canScheduleExactAlarms = await androidImplementation.canScheduleExactNotifications();

        if (canScheduleExactAlarms == false) {
          print('⚠️ Exact alarms not permitted, requesting permission...');

          // Request permission (this will open device settings)
          final bool? granted = await androidImplementation.requestExactAlarmsPermission();
          print('🔔 Exact alarm permission result: $granted');
          return granted ?? false;
        } else {
          print('✅ Exact alarms already permitted');
          return true;
        }
      }
      return true; // iOS or permission not needed
    } catch (e) {
      print('❌ Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Schedule a daily notification at specified time
  Future<void> scheduleDailyNotification({
    required int hour,
    required int minute,
  }) async {
    try {
      print('🔔 Scheduling daily notification for $hour:$minute');

      // Cancel any existing practice reminder notifications
      await _flutterLocalNotificationsPlugin.cancel(_practiceReminderNotificationId);

      // Calculate the next occurrence of the specified time
      final now = DateTime.now();
      var scheduledDate = DateTime(now.year, now.month, now.day, hour, minute);

      // If the time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      final tz.TZDateTime scheduledTZDateTime = tz.TZDateTime.from(
        scheduledDate,
        tz.local,
      );

      // Create notification details
      const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        'practice_reminder_channel',
        'Practice Reminders',
        channelDescription: 'Daily practice reminder notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6B35),
        playSound: true,
        enableVibration: true,
      );

      const DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      // Try exact scheduling first, fallback to inexact if not permitted
      try {
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          _practiceReminderNotificationId,
          '🎵 Practice Time!',
          'Ready for your daily music practice? Let\'s maintain that streak!',
          scheduledTZDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time, // This makes it repeat daily
          payload: 'practice_reminder',
        );
        print('✅ Daily notification scheduled (exact) for ${scheduledTZDateTime.toString()}');
      } catch (exactAlarmError) {
        print('⚠️ Exact alarm not permitted, falling back to inexact scheduling');

        // Fallback to inexact scheduling
        await _flutterLocalNotificationsPlugin.zonedSchedule(
          _practiceReminderNotificationId,
          '🎵 Practice Time!',
          'Ready for your daily music practice? Let\'s maintain that streak!',
          scheduledTZDateTime,
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: 'practice_reminder',
        );
        print('✅ Daily notification scheduled (inexact) for ${scheduledTZDateTime.toString()}');
      }
    } catch (e) {
      print('❌ Error scheduling daily notification: $e');
    }
  }

  /// Show an immediate notification (for testing or instant alerts)
  Future<void> showImmediateNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidNotificationDetails =
      AndroidNotificationDetails(
        'immediate_channel',
        'Immediate Notifications',
        channelDescription: 'Immediate notification messages',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        color: Color(0xFFFF6B35),
      );

      const DarwinNotificationDetails iosNotificationDetails =
      DarwinNotificationDetails(
        sound: 'default',
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails,
        iOS: iosNotificationDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        0, // Use ID 0 for immediate notifications
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      print('✅ Immediate notification shown: $title');
    } catch (e) {
      print('❌ Error showing immediate notification: $e');
    }
  }

  /// Show achievement notification
  Future<void> showAchievementNotification({
    required String achievementTitle,
    required String achievementDescription,
    String? uid, // Add uid parameter for storage
    String? achievementId, // Add achievementId for metadata
  }) async {
    await showImmediateNotification(
      title: '🏆 Achievement Unlocked!',
      body: '$achievementTitle - $achievementDescription',
      payload: 'achievement',
    );

    // Store in app if uid is provided
    if (uid != null) {
      await _storageService.storeAchievementNotification(
        uid: uid,
        achievementId: achievementId ?? '',
        achievementTitle: achievementTitle,
        description: achievementDescription,
      );
    }
  }

  /// Show streak milestone notification
  Future<void> showStreakNotification(int streakDays, {String? uid}) async {
    String title = '🔥 Streak Milestone!';
    String body = '';

    if (streakDays == 7) {
      body = 'Amazing! You\'ve reached a 7-day practice streak!';
    } else if (streakDays == 30) {
      body = 'Incredible! 30 days of consistent practice!';
    } else if (streakDays == 100) {
      body = 'Legendary! 100 days of dedication to music!';
    } else if (streakDays % 7 == 0) {
      body = 'Great job! ${streakDays} days of consistent practice!';
    }

    if (body.isNotEmpty) {
      await showImmediateNotification(
        title: title,
        body: body,
        payload: 'streak_$streakDays',
      );

      // Store in app if uid is provided
      if (uid != null) {
        await _storageService.storeStreakNotification(
          uid: uid,
          streakDays: streakDays,
        );
      }
    }
  }

  /// Show goal completion notification
  Future<void> showGoalCompletionNotification({String? uid, int? goalMinutes, int? completedMinutes}) async {
    await showImmediateNotification(
      title: '🎯 Daily Goal Achieved!',
      body: 'Congratulations! You\'ve completed your daily practice goal.',
      payload: 'goal_completed',
    );

    // Store in app if uid is provided
    if (uid != null) {
      await _storageService.storeGoalCompletionNotification(
        uid: uid,
        minutesCompleted: completedMinutes ?? 0,
        goalMinutes: goalMinutes ?? 30,
      );
    }
  }

  /// Cancel a specific notification
  Future<void> cancelNotification(int id) async {
    try {
      await _flutterLocalNotificationsPlugin.cancel(id);
      print('🔔 Notification $id cancelled');
    } catch (e) {
      print('❌ Error cancelling notification $id: $e');
    }
  }

  /// Cancel all notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _flutterLocalNotificationsPlugin.cancelAll();
      print('🔔 All notifications cancelled');
    } catch (e) {
      print('❌ Error cancelling all notifications: $e');
    }
  }

  /// Get list of pending notifications (for debugging)
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    try {
      final pendingNotifications = await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
      print('🔔 Pending notifications: ${pendingNotifications.length}');
      for (final notification in pendingNotifications) {
        print('  - ID: ${notification.id}, Title: ${notification.title}');
      }
      return pendingNotifications;
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
      return [];
    }
  }

  /// Check if notifications are enabled on the device
  Future<bool?> areNotificationsEnabled() async {
    try {
      return await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
    } catch (e) {
      print('❌ Error checking notification status: $e');
      return null;
    }
  }

  /// Test notification (for development/debugging)
  Future<void> testNotification() async {
    await showImmediateNotification(
      title: '🧪 Test Notification',
      body: 'This is a test notification from Swar Sathi!',
      payload: 'test',
    );
  }
}