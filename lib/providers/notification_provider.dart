import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config_provider.dart';
import '../services/notifications/notification_service.dart';

final notificationSyncProvider = Provider<void>((ref) {
  final enabled = ref.watch(remindersEnabledProvider);
  final annoying = ref.watch(annoyingModeProvider);
  final time = ref.watch(reminderTimeProvider);

  // Re-schedule notifications whenever config changes
  NotificationService.scheduleDailyReminders(
    enabled: enabled,
    annoyingMode: annoying,
    timeStr: time,
  );
});
