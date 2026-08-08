import 'package:flutter_test/flutter_test.dart';
import 'package:rounds/core/utils/notification_service.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  setUpAll(tzdata.initializeTimeZones);

  /// The UTC offset [name] actually resolves to. Etc/GMT zones have no DST, so
  /// the date is irrelevant.
  Duration offsetOf(String name) =>
      tz.TZDateTime(tz.getLocation(name), 2026, 8, 20, 9).timeZoneOffset;

  group('etcGmtZoneName', () {
    test('inverts the sign, per the POSIX convention', () {
      // The trap this whole function exists to contain: Etc/GMT+5 is UTC-5.
      expect(etcGmtZoneName(const Duration(hours: -5)), 'Etc/GMT+5');
      expect(etcGmtZoneName(const Duration(hours: 2)), 'Etc/GMT-2');
      expect(etcGmtZoneName(Duration.zero), 'Etc/GMT+0');
    });

    test('every whole-hour offset resolves back to itself', () {
      // Names that don't exist, or that resolve to the opposite offset, would
      // silently misfire every reminder — so assert against the real database
      // rather than against the string.
      for (var hours = -12; hours <= 14; hours++) {
        final offset = Duration(hours: hours);
        expect(
          offsetOf(etcGmtZoneName(offset)),
          offset,
          reason: 'UTC${hours >= 0 ? '+' : ''}$hours',
        );
      }
    });

    test('rounds a half-hour zone to within 30 minutes', () {
      // India (UTC+5:30) and Newfoundland (UTC-3:30) have no Etc/GMT name.
      for (final offset in [
        const Duration(hours: 5, minutes: 30),
        const Duration(hours: -3, minutes: -30),
        const Duration(hours: 5, minutes: 45), // Nepal
      ]) {
        final resolved = offsetOf(etcGmtZoneName(offset));
        expect((resolved - offset).abs(), lessThanOrEqualTo(const Duration(minutes: 30)));
      }
    });

    test('clamps offsets outside the range the names cover', () {
      // Nothing real lives out here, but a bad offset must still yield a name
      // that resolves instead of throwing.
      expect(etcGmtZoneName(const Duration(hours: -20)), 'Etc/GMT+12');
      expect(etcGmtZoneName(const Duration(hours: 20)), 'Etc/GMT-14');
      expect(offsetOf(etcGmtZoneName(const Duration(hours: 20))),
          const Duration(hours: 14));
    });

    test('beats the UTC it replaces for a real device offset', () {
      // Bogota: the old fallback fired 9:00 reminders at 4:00 in the morning.
      expect(offsetOf(etcGmtZoneName(const Duration(hours: -5))),
          const Duration(hours: -5));
    });
  });

  group('the zones the schedule depends on', () {
    test('latest_all carries the canonical zones latest_10y drops', () {
      // Why the bundled database is latest_all despite its parse cost: the
      // smaller ones lack these, and a device reporting one would fall back.
      for (final name in [
        'America/Ciudad_Juarez',
        'America/Nuuk',
        'America/Punta_Arenas',
        'America/Fort_Nelson',
        'Asia/Yangon',
        'Europe/Saratov',
        'Pacific/Bougainville',
      ]) {
        expect(() => tz.getLocation(name), returnsNormally, reason: name);
      }
    });
  });
}
