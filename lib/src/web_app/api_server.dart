import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:acanthis/src/operations/checks.dart';
import 'package:injector/injector.dart';
import 'package:nyxx/nyxx.dart';

import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/models/tag.dart';
import 'package:running_on_dart/src/modules/tag.dart';
import 'package:running_on_dart/src/web_app/jwt.dart';
import 'package:running_on_dart/src/web_app/mapper/guild_mapper.dart';
import 'package:running_on_dart/src/web_app/mapper/pagination_mapper.dart';
import 'package:running_on_dart/src/web_app/mapper/reminders_mapper.dart';
import 'package:running_on_dart/src/web_app/mapper/tags_mapper.dart';
import 'package:running_on_dart/src/web_app/utils.dart';
import 'package:running_on_dart/src/services/bot_info.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

import 'package:shelf_limiter/shelf_limiter.dart' as shelf_limiter;
import 'package:shelf_router/shelf_router.dart' as shelf_router;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'package:http/http.dart' as http;

import 'package:acanthis/acanthis.dart' as acanthis;

final clientId = getEnv('DISCORD_CLIENT_ID');
final clientSecret = getEnv('DISCORD_CLIENT_SECRET');
final clientRedirectUri = getEnv('DISCORD_REDIRECT_URI');

int _intOrDefault(String? value, int def) => int.tryParse(value ?? '$def') ?? def;

Snowflake? tryParseSnowflake(dynamic value) {
  if (value == null) {
    return null;
  }

  try {
    return Snowflake.parse(value);
  } on Exception {
    return null;
  }
}

class SnowflakeCheck extends AcanthisCheck<String> {
  const SnowflakeCheck() : super(error: 'Value is not valid snowflake', name: 'snowflake');

  @override
  bool call(String value) => tryParseSnowflake(value) != null;
}

extension SnowflakeValidion on acanthis.AcanthisString {
  acanthis.AcanthisString snowflake() {
    return withCheck(SnowflakeCheck());
  }
}

final tagPostSchema = acanthis.object({
  'name': acanthis.string().required().min(3).max(255),
  'content': acanthis.string().required().min(1).max(1024),
  'authorId': acanthis.string().required().snowflake(),
});

class WebServer {
  final Logger _logger = Logger('ROD.WebServer');

  Future<shelf.Response> _handleGuilds(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();

    final perPage = _intOrDefault(request.requestedUri.queryParameters['perPage'], 25);
    final page = _intOrDefault(request.requestedUri.queryParameters['page'], 1);

    final jwtPermissions = getJwtPermissionsFromRequest(request);

    var guilds = client.guilds.cache.values;
    var total = client.guilds.cache.length;
    if (!jwtPermissions.contains(JwtPermission.guilds.value)) {
      final userId = getLoggedInUserIdFromRequest(request);
      if (userId == null) {
        guilds = [];
        total = 0;
      } else {
        final userIdSnowflake = Snowflake.parse(userId);

        guilds = guilds.where((guild) {
          final member = guild.members.cache[userIdSnowflake];
          if (member == null) {
            return false;
          }

          return member.permissions?.isAdministrator ?? false;
        });

        total = guilds.length;
      }
    }

    guilds = guilds.skip(perPage * (page - 1)).take(perPage);

    return createOkResponse(
      createPaginationResponse(
        data: await mapGuildsToGuildReducedData(guilds).toList(),
        page: page,
        perPage: perPage,
        total: total,
      ),
    );
  }

  Future<shelf.Response> _handleGuildTags(shelf.Request request) async {
    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final perPage = int.tryParse(request.requestedUri.queryParameters['perPage'] ?? '5') ?? 5;
    final page = int.tryParse(request.requestedUri.queryParameters['page'] ?? '1') ?? 1;

    return createOkResponse(
      await mapGuildTagsToData(
        Snowflake.parse(guildParam),
        perPage,
        filters: request.requestedUri.queryParameters,
        page: page,
      ),
    );
  }

  Future<shelf.Response> _handleCreateGuildTag(shelf.Request request) async {
    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final body = await request.readAsString();
    final bodyJson = jsonDecode(body);

    final validationResult = tagPostSchema.tryParse(bodyJson);
    if (!validationResult.success) {
      return createValidationErrorResponse(validationResult.errors);
    }

    final authorId = tryParseSnowflake(bodyJson['authorId']);
    if (authorId == null) {
      return createValidationErrorResponse({'authorId': 'Not a valid snowflake'});
    }

    final tag = Tag(
      name: bodyJson['name'],
      content: bodyJson['content'],
      enabled: true,
      guildId: Snowflake.parse(guildParam),
      authorId: authorId,
    );

    final tagModule = Injector.appInstance.get<TagModule>();
    await tagModule.createTag(tag);

    return createOkResponse(mapGuildTag(tag));
  }

  Future<shelf.Response> _handleGuildReminders(shelf.Request request) async {
    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final perPage = int.tryParse(request.requestedUri.queryParameters['perPage'] ?? '5') ?? 5;
    final page = int.tryParse(request.requestedUri.queryParameters['page'] ?? '1') ?? 1;

    return createOkResponse(
      await mapRemindersToData(
        Snowflake.parse(guildParam),
        perPage,
        filters: request.requestedUri.queryParameters,
        page: page,
      ),
    );
  }

  Future<shelf.Response> _handleGuildDetails(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();

    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final channelsLimit = _intOrDefault(request.requestedUri.queryParameters['channelsLimit'], 0);
    final rolesLimit = _intOrDefault(request.requestedUri.queryParameters['rolesLimit'], 0);
    final tagsLimit = _intOrDefault(request.requestedUri.queryParameters['tagsLimit'], 5);

    try {
      final guild = await client.guilds.get(Snowflake.parse(guildParam));

      return createOkResponse(await mapGuildToDetailsData(guild, channelsLimit, rolesLimit, tagsLimit));
    } on HttpResponseError {
      return createNotFoundResponse();
    }
  }

  Future<shelf.Response> _handleGuildMember(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();

    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final memberParam = request.params['member_id'];
    if (memberParam == null) {
      return createBadRequestResponse("Missing member_id param");
    }

    try {
      final guild = await client.guilds.get(Snowflake.parse(guildParam));
      final member = await guild.members.get(Snowflake.parse(memberParam));

      return createOkResponse(mapMemberToData(guild, member));
    } on HttpResponseError {
      return createNotFoundResponse();
    }
  }

  Future<shelf.Response> _handleGuildChannel(shelf.Request request) async {
    final client = Injector.appInstance.get<NyxxGateway>();

    final guildParam = request.params['id'];
    if (guildParam == null) {
      return createBadRequestResponse("Missing id param");
    }

    final channelParam = request.params['channel_id'];
    if (channelParam == null) {
      return createBadRequestResponse("Missing channel_id param");
    }

    try {
      final channel = await client.channels.get(Snowflake.parse(channelParam));
      if (channel is! GuildChannel) {
        return createBadRequestResponse("Channel is not guild channel");
      }

      if ((channel).guildId != Snowflake.parse(guildParam)) {
        return createBadRequestResponse("Channel doesnt belong to provided guild");
      }

      return createOkResponse(mapChannelToData(channel));
    } on HttpResponseError {
      return createNotFoundResponse();
    }
  }

  Future<shelf.Response> _handleServerInfo(shelf.Request request) async {
    final data = await Injector.appInstance.get<BotInfoService>().getCurrentBotInfo();

    return createOkResponse(data.toJson());
  }

  Future<shelf.Response> _handleValidateCode(shelf.Request request) async {
    final authCode = request.url.queryParameters['code'];

    final tokenResponse = await http.post(
      Uri.https('discord.com', '/api/oauth2/token'),
      body: {
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': clientRedirectUri,
        'grant_type': 'authorization_code',
        'code': authCode,
      },
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );

    final tokenBodyJson = jsonDecode(tokenResponse.body);
    final token = tokenBodyJson['access_token'];

    final userData = await http.get(
      Uri.https('discord.com', '/api/oauth2/@me'),
      headers: {"Accept": "application/json", "Authorization": "Bearer $token"},
    );
    final userDataJson = jsonDecode(userData.body);

    final guildsData = await http.get(
      Uri.https('discord.com', '/api/users/@me/guilds'),
      headers: {"Accept": "application/json", "Authorization": "Bearer $token"},
    );
    final guildsDataJson = jsonDecode(guildsData.body);

    final userId = userDataJson['user']['id'] as String;

    final permissions = adminIds.contains(Snowflake.parse(userId)) ? JwtPermission.intValues() : <int>[];

    final jwtResponse = generateJwtResponse(
      userId,
      userData: {
        'id': userDataJson['user']['id'],
        'name': userDataJson['user']['global_name'] ?? userDataJson['user']['username'],
        'avatar': userDataJson['user']['avatar'],
        'guilds': guildsDataJson.map((guildData) => guildData['id']).toList(),
      },
      permissions: permissions,
    );

    return createOkResponse(jwtResponse);
  }

  Future<shelf.Response> _handleIndex(shelf.Request request) async {
    final content = await File('public/index.html').readAsString();

    return shelf.Response.ok(content, headers: {'content-type': 'text/html'});
  }

  Future<shelf_router.Router> _setupRouter() async {
    final staticHandler = createStaticHandler('public');

    return shelf_router.Router()
      ..get("/api/server-info", _handleServerInfo)
      ..get("/api/guilds", _requireJwt(_handleGuilds))
      ..get("/api/guilds/<id>", _requireJwt(_requireAdminUserOrPerms(_handleGuildDetails, [JwtPermission.guilds])))
      ..get("/api/guilds/<id>/tags", _requireJwt(_requireAdminUserOrPerms(_handleGuildTags, [JwtPermission.guilds])))
      ..post(
        "/api/guilds/<id>/tags",
        _requireJwt(_requireAdminUserOrPerms(_handleCreateGuildTag, [JwtPermission.guilds])),
      )
      ..get(
        "/api/guilds/<id>/reminders",
        _requireJwt(_requireAdminUserOrPerms(_handleGuildReminders, [JwtPermission.guilds])),
      )
      ..get(
        "/api/guilds/<id>/members/<member_id>",
        _requireJwt(_requireAdminUserOrPerms(_handleGuildMember, [JwtPermission.guilds])),
      )
      ..get(
        "/api/guilds/<id>/channels/<channel_id>",
        _requireJwt(_requireAdminUserOrPerms(_handleGuildChannel, [JwtPermission.guilds])),
      )
      ..get("/api/validate-oauth", _handleValidateCode)
      ..all(r"/<ignored|.+\w+\.\w+$>", staticHandler)
      ..all("/<ignored|.*>", _handleIndex);
  }

  shelf.Handler _requireJwt(shelf.Handler inner, [List<JwtPermission> permissions = const []]) =>
      shelf.Pipeline().addMiddleware(processJwt(permissions)).addHandler(inner);

  shelf.Handler _requireAdminUserOrPerms(shelf.Handler inner, [List<JwtPermission> orPermissions = const []]) =>
      shelf.Pipeline()
          .addMiddleware(processGuildUser(orPermissions: orPermissions.map((e) => e.value).toList()))
          .addHandler(inner);

  Future<void> startServer() async {
    if (!webServerEnabled) {
      _logger.info("Web server not enabled, skipping...");
      return;
    }

    final router = await _setupRouter();

    final corsChecker = dev ? originAllowAll : originOneOf(webServerAllowedOrigins.split(','));

    final limiter = shelf_limiter.shelfLimiterByEndpoint(
      endpointLimits: {
        '/api/*': shelf_limiter.RateLimiterOptions(maxRequests: 10, windowSize: const Duration(seconds: 10)),
      },
      defaultOptions: shelf_limiter.RateLimiterOptions(maxRequests: 120, windowSize: const Duration(minutes: 1)),
    );

    var pipeline = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(corsHeaders(originChecker: corsChecker));

    if (!dev) {
      pipeline = pipeline.addMiddleware(limiter);
    }

    final app = pipeline.addHandler(router.call);

    _logger.info("Starting server at: http://$webServerHost:$webServerPort/");
    await shelf_io.serve(app, webServerHost, webServerPort);
  }
}
