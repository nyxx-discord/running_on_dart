import 'package:dio/dio.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:running_on_dart/src/models/jellyfin_config.dart';
import 'package:running_on_dart/src/modules/jellyfin.dart';
import 'package:running_on_dart/src/util/jellyfin.dart';

Future<void> handleException(CommandsException error) async {
  if (error is CheckFailedException) {
    error.context.respond(MessageBuilder(content: "Sorry, you can't use that command!"));
    return;
  }

  if (error is ConverterFailedException && error.context is CommandContext) {
    switch (error.failed) {
      case Converter<JellyfinConfig>():
      case Converter<JellyfinConfigUser>():
        (error.context as CommandContext)
            .respond(MessageBuilder(content: "Cannot parse jellyfin config"), level: ResponseLevel.private);
        break;
    }

    return;
  }

  if (error is UncaughtException) {
    return _handleUncaughtException(error, error.context);
  }
}

Future<void> _handleUncaughtException(UncaughtException error, CommandContext context) async {
  switch (error.exception) {
    case JellyfinConfigNotFoundException(:final message):
      error.context.respond(MessageBuilder(content: message));
      break;
    case JellyfinAdminUserRequired _:
      context.respond(
          MessageBuilder(content: "This command can use only logged jellyfin users with administrator privileges."),
          level: ResponseLevel.private);
      break;
    case DioException(:final error) when error is JellyfinUnauthorizedException:
      final jellyfinConfigs = await Injector.appInstance
          .get<JellyfinModuleV2>()
          .getJellyfinConfigBasedOnPreviousLogin(context.user.id, context.guild?.id ?? context.user.id, error.host);

      if (jellyfinConfigs.length == 1) {
        final userConfig = jellyfinConfigs.first;
        final config =
            await Injector.appInstance.get<JellyfinModuleV2>().getJellyfinConfigById(userConfig.jellyfinConfigId);

        context.respond(
            getJellyfinLoginMessage(
                userId: userConfig.userId, configName: config!.name, parentId: config.parentId, isReAuth: true),
            level: ResponseLevel.private);
        break;
      }

      context.respond(
          MessageBuilder(content: 'Cannot provide config automatically. Login manually using: `/jellyfin user login`.'),
          level: ResponseLevel.private);
      break;
  }
}
