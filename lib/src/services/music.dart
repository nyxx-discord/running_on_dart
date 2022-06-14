import 'package:nyxx/nyxx.dart';
import 'package:nyxx_commands/nyxx_commands.dart';
import 'package:nyxx_lavalink/nyxx_lavalink.dart';
import 'package:running_on_dart/running_on_dart.dart';
import 'package:running_on_dart/src/util.dart';

/// The address of the lavalink running server to connect to.
String serverAddress = getEnv('LAVALINK_ADDRESS', 'localhost');

/// The port of the lavalink running server to use to connect.
int serverPort = int.parse(getEnv('LAVALINK_PORT', '2333'));

/// The password used to connect to the lavalink server.
String serverPassword = getEnv('LAVALINK_PASSWORD', 'testing');

/// Whether to use or not ssl to establish a connection.
bool useSSL = getEnvBool('LAVALINK_USE_SSL', false);

class MusicService {
  static MusicService get instance => _instance ?? (throw Exception('Music service must be initialised with MusicService.init'));
  static MusicService? _instance;

  final INyxxWebsocket _client;

  ICluster get cluster => _cluster ?? (throw Exception('Cluster must be accessed after `on_ready` event'));

  /// The cluster used to interact with lavalink
  ICluster? _cluster;

  MusicService._(this._client) {
    _client.onReady.listen((_) async {
      if (_cluster == null) {
        _cluster = ICluster.createCluster(_client, _client.appId);

        await cluster.addNode(NodeOptions(
            host: serverAddress,
            port: serverPort,
            password: serverPassword,
            ssl: useSSL,
            clientName: "RunningOnDart",
            shards: _client.shardManager.totalNumShards
        ));

        cluster.eventDispatcher.onTrackStart.listen(_trackStarted);
      }
    });
  }

  Future<void> _trackStarted(ITrackStartEvent event) async {
    final player = event.node.players[event.guildId];

    if (player != null && player.queue.isNotEmpty) {
      final track = player.queue[0];
      final embed = EmbedBuilder()
        ..color = getRandomColor()
        ..title = "Track started"
        ..description = "Track [${track.track.info?.title}](${track.track.info?.uri}) started playing.\n\nRequested by <@${track.requester!}>"
        ..thumbnailUrl = "https://img.youtube.com/vi/${track.track.info?.identifier}/hqdefault.jpg";

      await _client.httpEndpoints.sendMessage(track.channelId!, MessageBuilder.embed(embed));
    }
  }

  static void init(INyxxWebsocket client) {
    _instance = MusicService._(client);
  }
}

/// This exception is thrown when a check related to music commands fails
/// and it's used to notify about the error to the user.
class MusicCheckException extends CommandsException {
  final IContext context;
  MusicCheckException(this.context, super.message);
}
