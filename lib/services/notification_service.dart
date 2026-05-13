import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    // In newer versions flutter_timezone might return a String or TimezoneInfo.
    final String timeZoneName = tzInfo is String ? tzInfo : (tzInfo as dynamic).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher'); // Using default launcher icon

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);
    _isInitialized = true;
  }

  /// 1. Dynamic Daily Scheduling (Morning Habit & Escalation)
  Future<void> scheduleDailyNotifications(int completedDays) async {
    await _scheduleMorningNotification();
    await _scheduleEveningNotification(completedDays);
    await schedulePassiveAggressiveReminder();
  }

  /// Cancel Evening Notification on successful deposit
  Future<void> cancelEveningNotification() async {
    await _flutterLocalNotificationsPlugin.cancel(id: 1);
  }

  /// 4. Passive-Aggressive Reminder (Retention)
  Future<void> schedulePassiveAggressiveReminder() async {
    // 3 days into the future
    await _flutterLocalNotificationsPlugin.cancel(id: 2); // Cancel existing
    
    final scheduleTime = tz.TZDateTime.now(tz.local).add(const Duration(days: 3));

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 2,
      title: 'وينك؟ 🧐',
      body: 'يبدو أن تحقيق هدفك لم يعد من أولوياتك حالياً 😔. سنتوقف عن إرسال التذكيرات لك لبعض الوقت.',
      scheduledDate: scheduleTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'retention_channel',
          'Retention Notifications',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

    );
  }

  Future<void> _scheduleMorningNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduleTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (now.isAfter(scheduleTime)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    String title = 'صباح الإنجاز! ☀️';
    String body = '';

    // 2. Contextual & Time-Based Hooks
    if (scheduleTime.weekday == DateTime.thursday || scheduleTime.weekday == DateTime.friday) {
      body = 'الويكند بلّش والمصاريف رح تزيد! ادفع لحصالتك أولاً قبل ما تطير الفلوس.';
    } else if (scheduleTime.day == 30 || scheduleTime.day == 29) {
      body = 'الراتب نزل؟ كافئ نفسك المستقبلية واقتطع مبلغ لحصالة الـ 100 يوم اليوم.';
    } else {
      final morningQuotes = [
        'صباح الخير! وفرت ثمن قهوة اليوم؟ حطها بالحصالة وخلي بداية يومك إنجاز ☕',
        'قيمة إيداعك اليوم ممكن تنصرف على وجبة سريعة بتنساها بعد ساعة، أو تبني فيها حلمك. الخيار إلك!',
      ];
      body = morningQuotes[Random().nextInt(morningQuotes.length)];
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 0,
      title: title,
      body: body,
      scheduledDate: scheduleTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'morning_channel',
          'Morning Reminders',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleEveningNotification(int completedDays) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduleTime = tz.TZDateTime(tz.local, now.year, now.month, now.day, 21, 0);
    if (now.isAfter(scheduleTime)) {
      scheduleTime = scheduleTime.add(const Duration(days: 1));
    }

    String title = 'تنبيه! ⚠️';
    String body = 'الستريك تبعك في خطر! 🔥 لا تضيع تعب الأيام الماضية، سجل إيداعك الآن.';

    // 3. Milestone Teaser
    if ([23, 48, 73, 98].contains(completedDays)) {
      title = 'قربت توصل! 🚀';
      body = 'باقي يومين بس وتوصل لمحطة جديدة وتكسب مكافأتك! لا توقف هسا.';
    }

    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 1,
      title: title,
      body: body,
      scheduledDate: scheduleTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'evening_channel',
          'Evening Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,

    );
  }

  // 5. Debug method
  Future<void> testNotification(String title, String body) async {
    final scheduleTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 3));
    
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      id: 3,
      title: title,
      body: body,
      scheduledDate: scheduleTime,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'debug_channel',
          'Debug Notifications',
          importance: Importance.max,
          priority: Priority.max,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

    );
  }
}
