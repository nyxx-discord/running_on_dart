### Running on Dart

This is repo for a multipurpose bot, primarily built for developing [nyxx](https://github.com/l7ssha/nyxx) - Discord integration for Dart language.

## Running

The following environment variables are required to be set for Running on Dart to run:

Core bot settings
- `ROD_TOKEN`: The token for the bot account.
- `ROD_PREFIX` (optional, default `n>>`): The prefix to use for text commands.
- `ROD_INTENT_FEATURES_ENABLE`: A bool (`true` or `false`) indicating whether to enable features requiring privileged intents, namely `GUILD_MESSAGES` and `GUILD_MEMBERS`.
- `ROD_ADMIN_IDS`: The space-separated IDs (snowflakes) of the users that can use administrator commands.
- `ROD_DEV` (optional, default `false`): A bool indicating whether to run in development mode.
- `BOT_NAME` (optional, default `Nataly`): Displayed bot name in some contexts.

Documentation/GitHub settings
- `ROD_DOCS_UPDATE_INTERVAL` (optional, default `900`): The interval, in seconds, between documentation cache updates.
- `ROD_DOCS_PACKAGES` (optional, default `nyxx nyxx_interactions nyxx_commands nyxx_lavalink nyxx_extensions`): The space-separated names of the packages to include in documentation searches.
- `ROD_DEFAULT_DOCS_RESPONSE` (optional, default can be found in `src/settings.dart`): The content of the message to send when `!docs` or `docs info` is run.
- `ROD_DEFAULT_GITHUB_RESPONSE` (optional, default can be found in `src/settings.dart`): The content of the message to send when `!github` or `github info` is run.
- `ROD_GITHUB_ACCOUNT` (optional, default `nyxx-discord`): The GitHub account to use as the base for repository searches.
- `ROD_GITHUB_TOKEN` (optional): The GitHub Personal Access Token used to access the GitHub API.

Database (PostgreSQL)
- `DB_HOST` (optional, default `db`): Host of postgres database.
- `DB_PORT` (optional, default `5432`): Port of postgres database.
- `POSTGRES_USER` (required): Name of postgres user.
- `POSTGRES_DB` (required): Name of postgres db.
- `POSTGRES_PASSWORD` (required): Password of postgres user.

Web server
- `WEB_SERVER_ENABLE` (optional, default `0`): Enable the built-in web server (`1`/`0`).
- `WEB_SERVER_HOST` (optional, default `0.0.0.0`): Host/interface to bind the web server to.
- `WEB_SERVER_PORT` (optional, default `8088`): Port for the web server.
- `WEB_SERVER_ALLOWED_ORIGIN` (optional, default `https://localhost:8088`): Allowed origins for CORS headers.
- `DISCORD_CLIENT_ID` (optional): Discord OAuth2 application client ID.
- `DISCORD_CLIENT_SECRET` (optional): Discord OAuth2 application client secret.
- `DISCORD_REDIRECT_URI` (optional, default `https://localhost:8088/redirect`): OAuth2 redirect URI.
- `JWT_SECRET` (required when web server or JWT features enabled): Secret used to sign JWTs.

Metrics / Home Assistant (MQTT)
- `HOME_ASSISTANT_METRICS_MQTT_ENABLED` (optional, default `0`): Enable publishing metrics to MQTT (`1`/`0`).
- `METRICS_MQTT_PATH` (optional, default `127.0.0.1`): MQTT broker host or URL.
- `METRICS_MQTT_USERNAME` (optional): MQTT username.
- `METRICS_MQTT_PASSWORD` (optional): MQTT password.

Additionally, if `ROD_DEV` is `true`, the following environment variables must also be set:
- `ROD_DEV_GUILD_ID`: The ID (snowflake) of the guild to register commands to when developing.
- `ROD_ADMIN_GUILD` (optional): The ID (snowflake) of the admin guild, if used for admin-scoped features.

### Standalone

1. Set all the environment variables above.
2. Run `dart pub get` to install dependencies
3. Run `dart run nyxx_commands:compile -o bot.dart` to generate an executable.
4. Run the created `bot.exe` file.

### With Docker

1. Set all the above environment variables in a `.env` file in the project root.
2. Run `docker-compose up` to run the bot.

## With Makefile

1. Set all the above environment variables in a `.env` file in the project root.
2. Run `make run` to run the bot.
