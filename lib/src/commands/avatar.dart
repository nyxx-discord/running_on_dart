import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final avatar = ChatCommand(
  'avatar',
  "Get a user's avatar",
  id('avatar', (
    ChatContext context, [
    @Description('The user to fetch the avatar for') User? target,
    @Description("Whether to show the user's guild profile, if they have one") bool showGuildProfile = false,
  ]) async {
    final targetUser = target ?? context.user;

    if (showGuildProfile && context.guild != null) {
      final targetMember = await context.guild?.members.get(targetUser.id);

      return context
          .respond(MessageBuilder(content: targetMember?.avatar?.url.toString() ?? 'Cannot get member avatar.'));
    }

    return context.respond(MessageBuilder(content: targetUser.avatar.url.toString()));
  }),
);
