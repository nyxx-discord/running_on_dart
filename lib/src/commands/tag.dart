import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';

ChatCommand tag = ChatCommand.textOnly(
  'tag',
  'Create and manage tags',
  (IChatContext context, Tag tag) => context.respond(MessageBuilder.content(tag.content)),
  children: [
    ChatCommand(
      'create',
      'Create a new tag',
      (
        IChatContext context,
        @Description('The name of the tag') String name,
        @Description('The content of the tag') String content, [
        @Description('Whether to enable the tag by default') bool enabled = true,
      ]) async {
        if (TagService.instance.getByName(context.guild?.id ?? Snowflake.zero(), name) != null) {
          await context.respond(MessageBuilder.embed(
            EmbedBuilder()
              ..color = DiscordColor.red
              ..title = "Couldn't create tag"
              ..description = 'A tag with that name already exists in this server',
          ));
          return;
        }

        Tag tag = Tag(
          authorId: context.user.id,
          guildId: context.guild?.id ?? Snowflake.zero(),
          content: content,
          enabled: enabled,
          name: name,
        );

        await TagService.instance.createTag(tag);

        await context.respond(MessageBuilder.content('Tag created successfully!'));
      },
    ),
    ChatCommand(
      'show',
      'Show a tag',
      (
        IChatContext context,
        @Description('The tag to show') Tag tag,
      ) async {
        await context.respond(MessageBuilder.content(tag.content));
      },
    ),
    ChatCommand(
      'preview',
      'View a tag, without making it publically visible',
      (
        IChatContext context,
        @Description('The tag to preview') Tag tag,
      ) async {
        await context.respond(MessageBuilder.content(tag.content), private: true);
      },
    ),
    ChatCommand(
      'enable',
      'Enable a tag',
      (
        IChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to enable') Tag tag,
      ) async {
        if (tag.enabled) {
          await context.respond(MessageBuilder.content('That tag is already enabled!'));
          return;
        }

        tag.enabled = true;
        await TagService.instance.updateTag(tag);

        await context.respond(MessageBuilder.content('Successfully enabled tag!'));
      },
    ),
    ChatCommand(
      'disable',
      'Disable a tag',
      (
        IChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to disable') Tag tag,
      ) async {
        if (!tag.enabled) {
          await context.respond(MessageBuilder.content('That tag is already disabled!'));
          return;
        }

        tag.enabled = false;
        await TagService.instance.updateTag(tag);

        await context.respond(MessageBuilder.content('Successfully disabled tag!'));
      },
    ),
    ChatCommand(
      'delete',
      'Delete an existing tag',
      (
        IChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to delete') Tag tag,
      ) async {
        await TagService.instance.deleteTag(tag);

        await context.respond(MessageBuilder.content('Successfully deleted tag!'));
      },
    ),
  ],
);
