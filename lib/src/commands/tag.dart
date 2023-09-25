import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/util.dart';

ChatCommand tag = ChatCommand.textOnly(
  'tag',
  'Create and manage tags',
  id(
      'tag',
      (IChatContext context, Tag tag) =>
          context.respond(MessageBuilder.content(tag.content))),
  children: [
    ChatCommand(
      'create',
      'Create a new tag',
      id('tag-create', (
        IChatContext context,
        @Description('The name of the tag') String name,
        @Description('The content of the tag') String content, [
        @Description('Whether to enable the tag by default')
        bool enabled = true,
      ]) async {
        if (TagService.instance
                .getByName(context.guild?.id ?? Snowflake.zero(), name) !=
            null) {
          await context.respond(MessageBuilder.embed(
            EmbedBuilder()
              ..color = DiscordColor.red
              ..title = "Couldn't create tag"
              ..description =
                  'A tag with that name already exists in this server',
          ));
          return;
        }

        final tag = Tag(
          authorId: context.user.id,
          guildId: context.guild?.id ?? Snowflake.zero(),
          content: content,
          enabled: enabled,
          name: name,
        );

        await TagService.instance.createTag(tag);

        await context
            .respond(MessageBuilder.content('Tag created successfully!'));
      }),
    ),
    ChatCommand(
      'show',
      'Show a tag',
      id('tag-show', (
        IChatContext context,
        @Description('The tag to show') Tag tag,
      ) async {
        await context.respond(MessageBuilder.content(tag.content));

        await TagService.instance.registerTagUsedEvent(TagUsedEvent.fromTag(
          tag: tag,
          usedAt: DateTime.now(),
          hidden: false,
        ));
      }),
    ),
    ChatCommand(
      'preview',
      'View a tag, without making it publically visible',
      id('tag-preview', (
        IChatContext context,
        @Description('The tag to preview') Tag tag,
      ) async {
        await context.respond(MessageBuilder.content(tag.content),
            private: true);

        await TagService.instance.registerTagUsedEvent(TagUsedEvent.fromTag(
          tag: tag,
          usedAt: DateTime.now(),
          hidden: true,
        ));
      }),
    ),
    ChatCommand(
      'enable',
      'Enable a tag',
      id('tag-enable', (
        IChatContext context,
        @UseConverter(manageableTagConverter)
        @Description('The tag to enable')
        Tag tag,
      ) async {
        if (tag.enabled) {
          await context
              .respond(MessageBuilder.content('That tag is already enabled!'));
          return;
        }

        tag.enabled = true;
        await TagService.instance.updateTag(tag);

        await context
            .respond(MessageBuilder.content('Successfully enabled tag!'));
      }),
    ),
    ChatCommand(
      'disable',
      'Disable a tag',
      id('tag-disable', (
        IChatContext context,
        @UseConverter(manageableTagConverter)
        @Description('The tag to disable')
        Tag tag,
      ) async {
        if (!tag.enabled) {
          await context
              .respond(MessageBuilder.content('That tag is already disabled!'));
          return;
        }

        tag.enabled = false;
        await TagService.instance.updateTag(tag);

        await context
            .respond(MessageBuilder.content('Successfully disabled tag!'));
      }),
    ),
    ChatCommand(
      'delete',
      'Delete an existing tag',
      id('tag-delete', (
        IChatContext context,
        @UseConverter(manageableTagConverter)
        @Description('The tag to delete')
        Tag tag,
      ) async {
        await TagService.instance.deleteTag(tag);

        await context
            .respond(MessageBuilder.content('Successfully deleted tag!'));
      }),
    ),
    ChatCommand(
      'stats',
      'Show tag statistics',
      id('tag-stats', (
        IChatContext context, [
        @Description('The tag to show stats for') Tag? tag,
      ]) async {
        final events = TagService.instance
            .getTagUsage(context.guild?.id ?? Snowflake.zero(), tag)
            .toList();

        final totalUses = events.length;
        final totalHiddenUses = events.where((event) => event.hidden).length;

        final threeDaysAgo = DateTime.now().add(Duration(days: -3));
        final usesLastThreeDays =
            events.where((event) => event.usedAt.isAfter(threeDaysAgo)).length;
        final hiddenUsesLastThreeDays = events
            .where(
                (event) => event.usedAt.isAfter(threeDaysAgo) && event.hidden)
            .length;

        final embed = EmbedBuilder()
          ..color = getRandomColor()
          ..title = 'Tag stats${tag != null ? ': ${tag.name}' : ''}'
          ..addField(
            name: 'Total usage',
            content:
                '- Tag${tag == null ? 's' : ''} shown ${totalUses - totalHiddenUses} times\n'
                '- Tag${tag == null ? 's' : ''} previewed $totalHiddenUses times',
          )
          ..addField(
            name: 'Usage in the last 3 days',
            content:
                '- Tag${tag == null ? 's' : ''} shown ${usesLastThreeDays - hiddenUsesLastThreeDays} times\n'
                '- Tag${tag == null ? 's' : ''} previewed $hiddenUsesLastThreeDays times',
          );

        if (tag == null) {
          final useCount = <Tag, int>{};

          for (final event in events) {
            final tag = TagService.instance.getById(event.tagId);

            if (tag == null) {
              continue;
            }

            useCount[tag] = (useCount[tag] ?? 0) + 1;
          }

          if (useCount.isNotEmpty) {
            final top5 = (useCount.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value)))
                .map((entry) => entry.key)
                .take(5);

            embed.addField(
              name: 'Top tags',
              content: top5
                  .map((tag) => '- **${tag.name}** (${useCount[tag]})')
                  .join('\n'),
            );
          }
        }

        await context.respond(MessageBuilder.embed(embed));
      }),
    ),
  ],
);
