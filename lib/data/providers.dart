import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rounds/core/utils/notification_service.dart';

/// The notification service, behind a provider so code that schedules or
/// cancels reminders can be tested with a fake in its place.
final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService.instance,
);
