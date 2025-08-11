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

    test("Invalid/edge inputs return null", () {
      expect(AudioChannelLayout.parse(null), isNull);
      expect(AudioChannelLayout.parse(''), isNull);
      expect(AudioChannelLayout.parse('  '), isNull);
      expect(AudioChannelLayout.parse('abc'), isNull);
      expect(AudioChannelLayout.parse('2.'), isNull);
      expect(AudioChannelLayout.parse('.1'), isNull);
    });

    test("toString without aux channel prints 'main.sub'", () {
      final layout = AudioChannelLayout.parse('2.1')!;
      expect(layout.toString(), '2.1');
    });

    test("Prefix boundary: 3.x => Stereo, 4.x => Surround", () {
      expect(AudioChannelLayout.parse('3.0')!.toStringWithPrefix(), 'Stereo 3.0');
      expect(AudioChannelLayout.parse('4.0')!.toStringWithPrefix(), 'Surround 4.0');
    });
  });
}
