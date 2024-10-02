import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/util/util.dart';

import '../converter.dart';

final tag = ChatGroup(
  'tag',
  'Create and manage tags',
  children: [
    ChatCommand(
      'create',
      'Create a new tag',
      id('tag-create', (
        ChatContext context,
        @Description('The name of the tag') String name,
        @Description('The content of the tag') String content, [
        @Description('Whether to enable the tag by default') bool enabled = true,
      ]) async {
        if (TagModule.instance.getByName(context.guild?.id ?? context.user.id, name) != null) {
          await context.respond(MessageBuilder(embeds: [
            EmbedBuilder(
                color: DiscordColor.parseHexString("#FF0000"),
                title: 'Couldn\'t create tag',
                description: 'A tag with that name already exists in this server')
          ]));

          return;
        }

        final tag = Tag(
          authorId: context.user.id,
          guildId: context.guild?.id ?? context.user.id,
          content: content,
          enabled: enabled,
          name: name,
        );

        await TagModule.instance.createTag(tag);

        await context.respond(MessageBuilder(content: 'Tag created successfully!'));
      }),
    ),
    ChatCommand(
      'show',
      'Show a tag',
      id('tag-show', (
        ChatContext context,
        @Description('The tag to show') Tag tag,
      ) async {
        await context.respond(MessageBuilder(content: tag.content));

        await TagModule.instance.registerTagUsedEvent(TagUsedEvent.fromTag(
          tag: tag,
          hidden: false,
        ));
      }),
    ),
    ChatCommand(
        'preview',
        'View a tag, without making it publically visible',
        id('tag-preview', (
          ChatContext context,
          @Description('The tag to preview') Tag tag,
        ) async {
          await context.respond(MessageBuilder(content: tag.content));

          await TagModule.instance.registerTagUsedEvent(TagUsedEvent.fromTag(
            tag: tag,
            hidden: true,
          ));
        }),
        options: CommandOptions(defaultResponseLevel: ResponseLevel.private)),
    ChatCommand(
      'enable',
      'Enable a tag',
      id('tag-enable', (
        ChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to enable') Tag tag,
      ) async {
        if (tag.enabled) {
          await context.respond(MessageBuilder(content: 'That tag is already enabled!'));
          return;
        }

        tag.enabled = true;
        await TagModule.instance.updateTag(tag);

        await context.respond(MessageBuilder(content: 'Successfully enabled tag!'));
      }),
    ),
    ChatCommand(
      'disable',
      'Disable a tag',
      id('tag-disable', (
        ChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to disable') Tag tag,
      ) async {
        if (!tag.enabled) {
          await context.respond(MessageBuilder(content: 'That tag is already disabled!'));
          return;
        }

        tag.enabled = false;
        await TagModule.instance.updateTag(tag);

        await context.respond(MessageBuilder(content: 'Successfully disabled tag!'));
      }),
    ),
    ChatCommand(
      'delete',
      'Delete an existing tag',
      id('tag-delete', (
        ChatContext context,
        @UseConverter(manageableTagConverter) @Description('The tag to delete') Tag tag,
      ) async {
        await TagModule.instance.deleteTag(tag);

        await context.respond(MessageBuilder(content: 'Successfully deleted tag!'));
      }),
    ),
    ChatCommand(
      'stats',
      'Show tag statistics',
      id('tag-stats', (
        ChatContext context, [
        @Description('The tag to show stats for') Tag? tag,
      ]) async {
        final events = TagModule.instance.getTagUsage(context.guild?.id ?? context.user.id, tag).toList();

        final totalUses = events.length;
        final totalHiddenUses = events.where((event) => event.hidden).length;

        final threeDaysAgo = DateTime.now().add(Duration(days: -3));
        final usesLastThreeDays = events.where((event) => event.usedAt.isAfter(threeDaysAgo)).length;
        final hiddenUsesLastThreeDays =
            events.where((event) => event.usedAt.isAfter(threeDaysAgo) && event.hidden).length;

        final fields = [
          EmbedFieldBuilder(
              name: 'Total usage',
              value: '- Tag${tag == null ? 's' : ''} shown ${totalUses - totalHiddenUses} times\n'
                  '- Tag${tag == null ? 's' : ''} previewed $totalHiddenUses times',
              isInline: false),
          EmbedFieldBuilder(
              name: 'Usage in the last 3 days',
              value: '- Tag${tag == null ? 's' : ''} shown ${usesLastThreeDays - hiddenUsesLastThreeDays} times\n'
                  '- Tag${tag == null ? 's' : ''} previewed $hiddenUsesLastThreeDays times',
              isInline: false)
        ];

        if (tag == null) {
          final useCount = <Tag, int>{};

          for (final event in events) {
            final tag = TagModule.instance.getById(event.tagId);

            if (tag == null) {
              continue;
            }

            useCount[tag] = (useCount[tag] ?? 0) + 1;
          }

          if (useCount.isNotEmpty) {
            final top5 = (useCount.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
                .map((entry) => entry.key)
                .take(5);

            fields.add(EmbedFieldBuilder(
                name: 'Top tags',
                value: top5.map((tag) => '- **${tag.name}** (${useCount[tag]})').join('\n'),
                isInline: false));
          }
        }

        final embed = EmbedBuilder(
          fields: fields,
          color: getRandomColor(),
          title: 'Tag stats${tag != null ? ': ${tag.name}' : ''}',
        );

        await context.respond(MessageBuilder(embeds: [embed]));
      }),
    ),
  ],
);
