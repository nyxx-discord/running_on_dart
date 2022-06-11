import 'package:github/github.dart' as github;
import 'package:running_on_dart/running_on_dart.dart';

class Issue {
  final github.Issue source;
  final github.RepositorySlug repo;

  Issue(this.repo, this.source);

  bool get hasPullRequest => source.pullRequest != null;
  bool get hasAssignee => source.assignee != null || (source.assignees?.isNotEmpty ?? false);

  bool get isBlocked => source.labels.any((label) => label.name == 'blocked');
  bool get isHelpWanted => source.labels.any((label) => label.name == 'help wanted');

  bool get isClosed => source.isClosed;
}

class PullRequest {
  final github.PullRequest source;
  final github.RepositorySlug repo;

  final bool _needsReview;

  PullRequest(this.repo, this.source, {required bool needsReview}) : _needsReview = needsReview;

  bool get isClosed => source.closedAt != null;
  bool get isDraft => source.draft ?? false;

  bool get needsReview => !isDraft && !isClosed && _needsReview;
  String get reviewUrl => 'https://github.com/$githubAccount/${repo.name}/pull/${source.number}/files';

  bool get hasMilestone => source.milestone != null;
  String? get milestoneName => source.milestone?.title;
  String? get milestoneUrl => source.milestone != null ? 'https://github.com/$githubAccount/${repo.name}/milestone/${source.milestone!.number}' : null;
}

class GitHubStats {
  final String accountName;
  final String bio;
  final int repositoryCount;
  final int starCount;
  final int followers;

  const GitHubStats({
    required this.accountName,
    required this.bio,
    required this.repositoryCount,
    required this.starCount,
    required this.followers,
  });
}

class GitHubOrganizationStats extends GitHubStats {
  final int memberCount;

  const GitHubOrganizationStats({
    required this.memberCount,
    required super.accountName,
    required super.bio,
    required super.repositoryCount,
    required super.starCount,
    required super.followers,
  });
}
