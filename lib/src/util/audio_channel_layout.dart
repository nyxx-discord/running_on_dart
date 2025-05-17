final channelLayoutRegex = RegExp(r'(\d+)\.(\d+)(\.(\d+))?');

class AudioChannelLayout {
  final int mainSpeakersCount;
  final int subwoofersCount;
  final int? auxChannelsCount;

  AudioChannelLayout({required this.mainSpeakersCount, required this.subwoofersCount, required this.auxChannelsCount});

  static AudioChannelLayout? parse(String? channelLayout) {
    if (channelLayout == null || channelLayout.trim().isEmpty) {
      return null;
    }

    final matchedRegex = channelLayoutRegex.firstMatch(channelLayout);
    if (matchedRegex == null) {
      return null;
    }

    final mainSpeakersCount = int.tryParse(matchedRegex.group(1) ?? '');
    final subwoofersCount = int.tryParse(matchedRegex.group(2) ?? '');
    final auxChannelsCount = int.tryParse(matchedRegex.group(4) ?? '');

    if (mainSpeakersCount == null || subwoofersCount == null) {
      return null;
    }

    return AudioChannelLayout(
      mainSpeakersCount: mainSpeakersCount,
      subwoofersCount: subwoofersCount,
      auxChannelsCount: auxChannelsCount,
    );
  }

  String toStringWithPrefix() {
    final prefix = mainSpeakersCount > 3 ? 'Surround' : 'Stereo';

    return '$prefix ${toString()}';
  }

  @override
  String toString() => '$mainSpeakersCount.$subwoofersCount${auxChannelsCount != null ? '.$auxChannelsCount' : ''}';
}
