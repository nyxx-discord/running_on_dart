import 'package:github/github.dart' as github;
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/github.dart';

class GitHubService {
  static final GitHubService instance = GitHubService._();

  final github.GitHub client =
      github.GitHub(auth: github.Authentication.withToken(githubToken));

  GitHubService._();

  Stream<Issue> fetchIssues({String? packageName, bool includeClosed = false}) {
    List<String> packages = docsPackages;

    if (packageName != null) {
      packages = [packageName];
    }

    return Stream.fromIterable(packages).asyncExpand(
      (package) => client.issues
          .listByRepo(
            github.RepositorySlug(githubAccount, package),
            perPage: 100,
            state: includeClosed ? 'all' : null,
          )
          .map(
            (issue) =>
                Issue(github.RepositorySlug(githubAccount, package), issue),
          ),
    );
  }

  Stream<PullRequest> fetchPullRequests(
      {String? packageName, bool includeClosed = false}) {
    List<String> packages = docsPackages;

    if (packageName != null) {
      packages = [packageName];
    }

    return Stream.fromIterable(packages).asyncExpand(
      (package) => client.pullRequests
          .list(
            github.RepositorySlug(githubAccount, package),
            state: includeClosed ? 'all' : 'open',
          )
          .asyncMap(
            (pullRequest) async => PullRequest(
              github.RepositorySlug(githubAccount, package),
              pullRequest,
              needsReview: await client.pullRequests
                  .listReviews(github.RepositorySlug(githubAccount, package),
                      pullRequest.number!)
                  .isEmpty,
            ),
          ),
    );
  }

  Future<GitHubStats?> fetchStats([String? accountName]) async {
    accountName ??= githubAccount;

    final starCount = await client.repositories
        .listUserRepositories(accountName)
        .fold<int>(0, (acc, repo) => acc + repo.stargazersCount);

    try {
      final organization = await client.organizations.get(accountName);

      return GitHubOrganizationStats(
        memberCount: await client.organizations.listUsers(accountName).length,
        accountName: accountName,
        repositoryCount: organization.publicReposCount ?? 0,
        starCount: starCount,
        followers: organization.followersCount ?? 0,
        bio: organization.name ?? '',
      );
    } on github.OrganizationNotFound {
      final user = await client.users.getUser(accountName);

      return GitHubStats(
        accountName: accountName,
        repositoryCount: user.publicReposCount ?? 0,
        starCount: starCount,
        followers: user.followersCount ?? 0,
        bio: user.bio ?? '',
      );
    }
  }
}
