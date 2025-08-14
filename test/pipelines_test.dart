import 'package:running_on_dart/src/util/pipelines.dart';
import 'package:test/test.dart';

void main() {
  group('pipelines helpers', () {
    test('getEmbedTitle returns "Task i of n"', () {
      expect(getEmbedTitle(1, 3), 'Task 1 of 3');
      expect(getEmbedTitle(3, 3), 'Task 3 of 3');
    });

    test('getInitialEmbed initializes title/description/author', () {
      final embed = getInitialEmbed(2, 'Build');

      expect(embed.title, 'Task 1 of 2');
      expect(embed.description, 'Starting...');
      expect(embed.author?.name, 'Pipeline Build');
    });
  });
}
