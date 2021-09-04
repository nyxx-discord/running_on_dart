### Running on Dart

This is repo for a multipurpose bot, primarily built for developing [nyxx](https://github.com/l7ssha/nyxx) - discord integration for Dart language.

#### Configuration

Bot requires environment variables to be set before starting:
 - `ROD_PREFIX` - prefix for chan commands
 - `ROD_TOKEN` - bot token
 - `ROD_INTENT_FEATURES_ENABLE` - if member intent features should be enabled (`false` by default)
 - `DB_HOST` - host of postgres database (`db` when using built in docker)
 - `DB_PORT` - port of postgres database (`5432` when using built in docker)
 - `POSTGRES_PASSWORD` - password of postgres user
 - `POSTGRES_USER` - name of postgres user
 - `POSTGRES_DB` - name of postgres db
