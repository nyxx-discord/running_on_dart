import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_pagination/nyxx_pagination.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/docs.dart';
import 'package:running_on_dart/src/models/github.dart';
import 'package:running_on_dart/src/services/github.dart';
import 'package:running_on_dart/src/util.dart';

final github = ChatCommand.textOnly(
  'github',
  'Get information about nyxx on GitHub',
  id('github', (MessageChatContext context) => context.respond(MessageBuilder.content(defaultGithubResponse.trim()))),
  children: [
    ChatCommand(
      'info',
      "General information about nyxx's GitHub",
      id('github-info', (IChatContext context) => context.respond(MessageBuilder.content(defaultGithubResponse.trim()))),
    ),
    ChatCommand(
      'issues',
      'Get information about issues on GitHub',
      id(
        'github-issues',
        (
          IChatContext context, [
          @Description('The package to fetch issues for') PackageDocs? package,
          @Description('Whether to include closed issues in the result') bool includeClosed = false,
        ]) async {
          final issues = await GitHubService.instance
              .fetchIssues(
                packageName: package?.packageName,
                includeClosed: includeClosed,
              )
              .toList();

          if (issues.isEmpty) {
            await context.respond(MessageBuilder.embed(
              EmbedBuilder()
                ..title = 'No issues'
                ..color = DiscordColor.red
                ..description = 'There are currently no issues open${package == null ? '' : ' for `${package.packageName}`'}.',
            ));
            return;
          }

          issues.sort(((a, b) {
            if (a.isClosed != b.isClosed) {
              return a.isClosed ? 1 : -1;
            }

            if (a.isHelpWanted != b.isHelpWanted) {
              return a.isHelpWanted ? -1 : 1;
            }

            if (a.isBlocked != b.isBlocked) {
              return a.isBlocked ? 1 : -1;
            }

            if (a.repo.name != b.repo.name) {
              return a.repo.name.compareTo(b.repo.name);
            }

            return a.source.number.compareTo(b.source.number);
          }));

          var pageCount = 1;

          final paginator = EmbedComponentPagination(
            context.commands.interactions,
            issues
                .fold<List<List<String>>>(
                  [[]],
                  (pages, issue) {
                    final issuePrefix = package == null ? '${issue.repo.name} #' : '#';

                    String content = '$issuePrefix${issue.source.number} - [${issue.source.title}](${issue.source.htmlUrl})';

                    final badges = [
                      if (issue.isClosed) '(Closed)',
                      if (issue.isHelpWanted) '(Help Wanted)',
                      if (issue.isBlocked) '(Blocked)',
                      if (issue.hasAssignee) '(Has Assignee)',
                      if (issue.hasPullRequest) '([Has Pull Request](${issue.source.pullRequest?.htmlUrl}))',
                    ];

                    if (badges.isNotEmpty) {
                      content += ' **${badges.join('** **')}**';
                    }

                    // +1 for newline
                    final wouldBeLength = pages.last.join('\n').length + content.length + 1;

                    if (wouldBeLength > 1024 || pages.last.length >= 10) {
                      pages.add([]);
                      pageCount++;
                    }

                    return pages..last.add(content);
                  },
                )
                .asMap()
                .entries
                .map((entry) {
                  final color = getRandomColor();

                  return EmbedBuilder()
                    ..color = color
                    ..description = 'Showing the top 100 issues from ${package == null ? 'all repositories' : '`${package.packageName}`'}.'
                        '${package != null ? ' Go to <https://github.com/$githubAccount/${package.packageName}/issues> for more.' : ''}'
                    ..addField(
                      name: 'Issues',
                      content: entry.value.join('\n'),
                    )
                    ..addFooter((footer) {
                      footer.text = 'Page ${entry.key + 1} of $pageCount';
                    });
                })
                .toList(),
          );

          await context.respond(paginator.initMessageBuilder());
        },
      ),
    ),
    ChatCommand(
      'pull-requests',
      'Get information about pull requests on GitHub',
      id(
        'github-pull-requests',
        (
          IChatContext context, [
          @Description('The package to fetch docs for') PackageDocs? package,
          @Description('Whether to include closed pull requests in the result') bool includeClosed = false,
        ]) async {
          final pulls = await GitHubService.instance
              .fetchPullRequests(
                packageName: package?.packageName,
                includeClosed: includeClosed,
              )
              .toList();

          if (pulls.isEmpty) {
            await context.respond(MessageBuilder.embed(
              EmbedBuilder()
                ..title = 'No pull requests'
                ..color = DiscordColor.red
                ..description = 'There are currently no pull requests open${package == null ? '' : ' for `${package.packageName}`'}.',
            ));
            return;
          }

          pulls.sort(((a, b) {
            if (a.isClosed != b.isClosed) {
              return a.isClosed ? 1 : -1;
            }

            if (a.needsReview != b.needsReview) {
              return a.needsReview ? -1 : 1;
            }

            if (a.repo.name != b.repo.name) {
              return a.repo.name.compareTo(b.repo.name);
            }

            if (a.milestoneName != b.milestoneName) {
              if (a.milestoneName == null) {
                return 1;
              }

              if (b.milestoneName == null) {
                return -1;
              }

              return a.milestoneName!.compareTo(b.milestoneName!);
            }

            return a.source.number?.compareTo(b.source.number ?? 0) ?? 1;
          }));

          var pageCount = 1;

          final paginator = EmbedComponentPagination(
            context.commands.interactions,
            pulls
                .fold<List<List<String>>>(
                  [[]],
                  (pages, pull) {
                    final pullPrefix = package != null ? '${package.packageName} #' : '#';

                    String content = '$pullPrefix${pull.source.number} - [${pull.source.title}](${pull.source.htmlUrl})';

                    final badges = [
                      if (pull.isClosed) '(Closed)',
                      if (pull.isDraft) '(Draft)',
                      if (pull.needsReview) '([Needs Review](${pull.reviewUrl}))',
                      if (pull.hasMilestone) '([${pull.milestoneName}](${pull.milestoneUrl}))',
                    ];

                    if (badges.isNotEmpty) {
                      content += ' **${badges.join('** **')}**';
                    }

                    // +1 for newline
                    final wouldBeLength = pages.last.join('\n').length + content.length + 1;

                    if (wouldBeLength > 1024 || pages.last.length >= 10) {
                      pages.add([]);
                      pageCount++;
                    }

                    return pages..last.add(content);
                  },
                )
                .asMap()
                .entries
                .map((entry) {
                  final color = getRandomColor();

                  return EmbedBuilder()
                    ..color = color
                    ..description = 'Showing the top 100 pull requests from ${package == null ? 'all repositories' : '`${package.packageName}`'}.'
                        '${package != null ? ' Go to <https://github.com/$githubAccount/${package.packageName}/pulls> for more.' : ''}'
                    ..addField(
                      name: 'Pull requests',
                      content: entry.value.join('\n'),
                    )
                    ..addFooter((footer) {
                      footer.text = 'Page ${entry.key + 1} of $pageCount';
                    });
                })
                .toList(),
          );

          await context.respond(paginator.initMessageBuilder());
        },
      ),
    ),
    ChatCommand(
      'stats',
      'Statistics about the $githubAccount GitHub organization.',
      id(
        'github-stats',
        (
          IChatContext context, [
          @Description('The name of the account to get stats for') String? accountName,
        ]) async {
          final stats = await GitHubService.instance.fetchStats(accountName);

          if (stats == null) {
            await context.respond(MessageBuilder.embed(
              EmbedBuilder()
                ..title = 'Account not found'
                ..description = "Couldn't fetch statistics for account $accountName"
                ..color = DiscordColor.red,
            ));
            return;
          }

          String response;

          if (stats is GitHubOrganizationStats) {
            response = '''
__${stats.accountName}: **${stats.bio}**__

**${stats.memberCount}** members.
**${stats.repositoryCount}** repositories.
**${stats.starCount}** stars.
**${stats.followers}** followers.
''';
          } else {
            response = '''
**${stats.accountName}**
${stats.bio}

**${stats.repositoryCount}** repositories.
**${stats.starCount}** stars.
**${stats.followers}** followers.
''';
          }

          await context.respond(MessageBuilder.content(response.trim()));
        },
      ),
    ),
  ],
);
