import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';

final avatar = ChatCommand(
  'avatar',
  "Get a user's avatar",
  id('avatar', (
    ChatContext context, [
    @Description('The user to fetch the avatar for') Member? target,
    @Description("Whether to show the user's guild profile, if they have one") bool showGuildProfile = true,
  ]) async {
    // Default to the user who invoked the command
    target ??= context.member;

    Uri? avatarUrl;

    // Try to fetch the guild profile
    if (showGuildProfile) {
      avatarUrl = target?.avatar?.url;
    }

    // Default to the user avatar
    avatarUrl ??= target?.user?.avatar.url;

    final content = avatarUrl?.toString() ?? "Cannot obtain avatar Url";
    await context.respond(MessageBuilder(content: content));
  }),
);
