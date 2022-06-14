import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/services/music.dart';
import 'package:running_on_dart/src/settings.dart';

final administratorCheck = UserCheck.anyId(adminIds, 'Administrator check');

final connectedToAVoiceChannelCheck = Check((IContext context) async {
  final selfMember = await context.guild!.selfMember.getOrDownload();

  if (selfMember.voiceState == null || selfMember.voiceState!.channel == null) {
    throw MusicCheckException(context, "I have to be in a voice channel to use this command");
  }
  return true;
});

final notConnectedToAVoiceChannelCheck = Check((IContext context) async {
  final selfMember = await context.guild!.selfMember.getOrDownload();

  if (selfMember.voiceState == null || selfMember.voiceState!.channel == null) {
    return true;
  }
  throw MusicCheckException(context, "I'm already connected to a voice channel");
});

final sameVoiceChannelOrDisconnectedCheck = Check((IContext context) async {
  // If this is an interaction, acknowledge it just in case the check
  // takes too long to run.
  if (context is InteractionChatContext) {
    await context.acknowledge();
  }

  final selfMemberVoiceState = (await context.guild!.selfMember.getOrDownload()).voiceState;
  final memberVoiceState = context.member!.voiceState;

  if (memberVoiceState == null || memberVoiceState.channel == null) {
    throw MusicCheckException(context, "You need to be connected to a voice channel to use this command");
  }

  if (selfMemberVoiceState == null || selfMemberVoiceState.channel == null) {
    return true;
  }

  if (selfMemberVoiceState.channel!.id != memberVoiceState.channel!.id) {
    throw MusicCheckException(context, "I'm already being used on other voice channel");
  }
  return true;
});
