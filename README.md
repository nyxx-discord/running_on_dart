### Running on Dart

This is repo for a multipurpose bot, primarily built for developing [nyxx](https://github.com/l7ssha/nyxx) - Discord integration for Dart language.

## Running

The following environment variables are required to be set for Running on Dart to run:
- `ROD_TOKEN`: The token for the bot account.
- `ROD_INTENT_FEATURES_ENABLE`: A bool (`true` or `false`) indicating whether to enable features requiring privileged intents, namely `GUILD_MESSAGES` and `GUILD_MEMBERS`.
- `ROD_PREFIX`: The prefix to use for text commands.
- `ROD_ADMIN_IDS`: The space-separated IDs (snowflakes) of the users that can use administrator commands.
- `ROD_DEV`: A bool (`true` or `false`) indicating whether to run in development mode.

Additionally, if `ROD_DEV` is `true`, the following environment variables must also be set:
- `ROD_DEV_GUILD_ID`: The ID (snowflake) of the guild to register commands to when developing.
