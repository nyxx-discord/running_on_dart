import 'package:running_on_dart/src/util/audio_channel_layout.dart';
import 'package:test/test.dart';

void main() {
  group("AudioChannelLayout", () {
    test("Stereo", () {
      final layout = AudioChannelLayout.parse('2.1');

      expect(layout, isNotNull);
      expect('Stereo 2.1', layout!.toStringWithPrefix());
    });

    test("Surround 7.1.4", () {
      final layout = AudioChannelLayout.parse('7.1.4');

      expect(layout, isNotNull);
      expect('Surround 7.1.4', layout!.toStringWithPrefix());
    });
  });
}
