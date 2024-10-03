### Running on Dart

This is repo for a multipurpose bot, primarily built for developing [nyxx](https://github.com/l7ssha/nyxx) - Discord integration for Dart language.

## Running

The following environment variables are required to be set for Running on Dart to run:
- `ROD_TOKEN`: The token for the bot account.
- `ROD_INTENT_FEATURES_ENABLE`: A bool (`true` or `false`) indicating whether to enable features requiring privileged intents, namely `GUILD_MESSAGES` and `GUILD_MEMBERS`.
- `ROD_PREFIX`: The prefix to use for text commands.
- `ROD_ADMIN_IDS`: The space-separated IDs (snowflakes) of the users that can use administrator commands.
- `ROD_DOCS_UPDATE_INTERVAL` (optional, default `900`): The interval, in seconds, between documentation cache updates.
- `ROD_DOCS_PACKAGES` (optional, default `nyxx nyxx_interactions nyxx_commands nyxx_lavalink nyxx_extensions`): The space-separated names of the packages to include in documentation searches.
- `ROD_DEFAULT_DOCS_RESPONSE` (optional, default can be found in `src/settings.dart`): The content of the message to send when `!docs` or `docs info` is run.
- `ROD_DEV`: A bool (`true` or `false`) indicating whether to run in development mode.
- `POSTGRES_PASSWORD` (optional): password of postgres user.
- `POSTGRES_USER`: name of postgres user.
- `POSTGRES_DB`: name of postgres db.
- `DB_HOST` (optional, default `db`): host of postgres database
- `DB_PORT` (optional, default `5432`): port of postgres database
- `ROD_DEFAULT_GITHUB_RESPONSE` (optional, default can be found in `src/settings.dart`): The content of the message to send when `!github` or `github info` is run.
- `ROD_GITHUB_ACCOUNT` (optional, default `nyxx-discord`): The GitHub account to use as the base for repository searches.
- `ROD_GITHUB_TOKEN`: The GitHub Personal Access Token used to access the GitHub API.

Additionally, if `ROD_DEV` is `true`, the following environment variables must also be set:
- `ROD_DEV_GUILD_ID`: The ID (snowflake) of the guild to register commands to when developing.

### Standalone

1. Set all the environment variables above.
2. Run `dart pub get` to install dependencies
3. Run `dart run nyxx_commands:compile -o bot.dart` to generate an executable.
4. Run the created `bot.exe` file.

### With Docker

1. Set all the above environment variables in a `.env` file in the project root.
3. Run `docker-compose up` to run the bot.
