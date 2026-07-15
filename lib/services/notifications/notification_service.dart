import 'dart:math';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static const List<String> _messages = [
    "Don't let your English get rusty! Gemini is waiting for a chat. 🤖",
    "Time for your daily dose of English! 🇬🇧",
    "Feeling talkative? Let's practice some English! 🗣️",
    "Angličtina nepočká! Pojďme si chvilku popovídat. 🚀",
    "Hey! Gemini has a new scenario for you. Check it out! ✨",
    "Just 5 minutes of speaking can make a huge difference. 📈",
    "Don't make me be annoying... oh wait, that's my job! Start training! 😈",
  ];

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Zde lze řešit navigaci po kliknutí na notifikaci
        debugPrint('Notifikace kliknuta: ${details.payload}');
      },
    );
  }

  static Future<void> scheduleDailyReminders({
    required bool enabled,
    required bool annoyingMode,
    required String timeStr,
  }) async {
    // Nejdříve zrušíme všechny staré notifikace
    await _notifications.cancelAll();

    if (!enabled) return;

    final timeParts = timeStr.split(':');
    final hour = int.parse(timeParts[0]);
    final minute = int.parse(timeParts[1]);

    // Hlavní denní notifikace
    await _scheduleNotification(
      id: 0,
      title: 'AJ Tudor Training',
      body: _getRandomMessage(),
      hour: hour,
      minute: minute,
    );

    // Pokud je aktivní "Otravný režim", přidáme další notifikace
    if (annoyingMode) {
      // Notifikace ráno v 9:00 (pokud není hlavní v tu dobu)
      if (hour != 9) {
        await _scheduleNotification(
          id: 1,
          title: 'Morning English Pulse',
          body: 'Start your day with some English! ☕',
          hour: 9,
          minute: 0,
        );
      }
      
      // Notifikace večer ve 21:00
      if (hour != 21) {
        await _scheduleNotification(
          id: 2,
          title: 'Bedtime Practice',
          body: 'One last chat before sleep? Gemini is up! 🌙',
          hour: 21,
          minute: 0,
        );
      }
    }
  }

  static Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'aj_tudor_reminders',
          'Training Reminders',
          channelDescription: 'Daily reminders to practice English',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static String _getRandomMessage() {
    return _messages[Random().nextInt(_messages.length)];
  }
}
