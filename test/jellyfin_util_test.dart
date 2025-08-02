import 'package:running_on_dart/src/util/jellyfin.dart';
import 'package:test/test.dart';

void main() {
  group('jellyfin util formatting helpers', () {
    test('parseDurationFromTicks converts ticks to Duration', () {
      expect(parseDurationFromTicks(10 * 1000 * 1000), const Duration(seconds: 1));
      expect(parseDurationFromTicks(0), const Duration(microseconds: 0));
      expect(parseDurationFromTicks(15), const Duration(microseconds: 1));
    });

    test('formatSeriesEpisodeString formats SxxExx', () {
      expect(formatSeriesEpisodeString(1, 1), 'S01E01');
      expect(formatSeriesEpisodeString(12, 34), 'S12E34');
      expect(formatSeriesEpisodeString(0, 9), 'S00E09');
    });

    test('formatProgress shows current/total and percentage', () {
      final current = 5 * 10 * 1000 * 1000;
      final total = 20 * 10 * 1000 * 1000;
      expect(formatProgress(current, total), '00:00:05/00:00:20 (25.00%)');
    });
  });
}
