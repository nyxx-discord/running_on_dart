import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/settings.dart';

final administratorCheck = UserCheck.anyId(adminIds, 'Administrator check');

final connectedToAVoiceChannelCheck = Check((IContext context) async {
  final selfMember = await context.guild!.selfMember.getOrDownload();

  if (selfMember.voiceState == null || selfMember.voiceState!.channel == null) {
    await context.respond(MessageBuilder.content('I have to be in a voice channel to use this command'));
    return false;
  }
  return true;
}, 'musicConnectedToVC');

final notConnectedToAVoiceChannelCheck = Check((IContext context) async {
  final selfMember = await context.guild!.selfMember.getOrDownload();

  if (selfMember.voiceState == null || selfMember.voiceState!.channel == null) {
    return true;
  }
  await context.respond(MessageBuilder.content("I'm already connected to a voice channel"));
  return false;
}, 'musicNotConnectedToVC');

final sameVoiceChannelOrDisconnectedCheck = Check((IContext context) async {
  // If this is an interaction, acknowledge it just in case the check
  // takes too long to run.
  if (context is InteractionChatContext) {
    await context.acknowledge();
  }

  final selfMemberVoiceState = (await context.guild!.selfMember.getOrDownload()).voiceState;
  // The upper check should be executed before, so its okay to assume the voice
  // state exists
  final memberVoiceState = context.member!.voiceState!;

  if (selfMemberVoiceState == null || selfMemberVoiceState.channel == null) {
    return true;
  }

  if (selfMemberVoiceState.channel!.id != memberVoiceState.channel!.id) {
    await context.respond(MessageBuilder.content("I'm already being used on other voice channel"));
    return false;
  }
  return true;
}, 'musicSameVC');

final userConnectedToVoiceChannelCheck = Check((IContext context) async {
  final memberVoiceState = context.member!.voiceState;

  if (memberVoiceState == null || memberVoiceState.channel == null) {
    return false;
  }
}, 'musicUserConnectedToVC');
