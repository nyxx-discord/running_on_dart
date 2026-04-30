import 'package:running_on_dart/src/util/rcon.dart';

// Re-export all RCON classes and exceptions for convenience
export 'package:running_on_dart/src/util/rcon.dart'
    show
        RconClient,
        RconException,
        RconAuthenticationException,
        RconConnectionException,
        RconTimeoutException,
        RconProtocolException,
        RconPacket,
        defaultRconPort,
        defaultRconTimeout,
        serverdataAuth,
        serverdataAuthResponse,
        serverdataExecCommand,
        serverdataResponseValue;

/// Data Transfer Object for Minecraft server information
class MinecraftServerInfo {
  /// Raw response from the 'list' command
  final String playersRaw;

  /// Raw response from the 'version' command
  final String versionRaw;

  /// Parsed list of player names
  final List<String> players;

  /// Parsed server version string
  final String version;

  MinecraftServerInfo({
    required this.playersRaw,
    required this.versionRaw,
    required this.players,
    required this.version,
  });

  @override
  String toString() => 'MinecraftServerInfo(version: "$version", players: $players)';

  /// Create server info from raw command responses
  factory MinecraftServerInfo.fromRawResponses(String playersRaw, String versionRaw) {
    return MinecraftServerInfo(
      playersRaw: playersRaw,
      versionRaw: versionRaw,
      players: _parsePlayerList(playersRaw),
      version: _parseVersion(versionRaw),
    );
  }

  /// Parse player names from the 'list' command response
  static List<String> _parsePlayerList(String response) {
    final cleaned = _parseRconResponse(response);

    final players = <String>[];

    // Try to match the pattern "There are X of a max of Y players online: ..."
    final match1 = RegExp(r'There are \d+ of a max of \d+ players online: (.+)').firstMatch(cleaned);
    if (match1 != null) {
      final playerList = match1.group(1)!;
      players.addAll(playerList.split(',').map((p) => p.trim()));
      return players;
    }

    // Try to match the pattern "players: (X) [...]"
    final match2 = RegExp(r'players?: \(\d+\) \[(.+)\]').firstMatch(cleaned);
    if (match2 != null) {
      final playerList = match2.group(1)!;
      players.addAll(playerList.split(',').map((p) => p.trim()));
      return players;
    }

    // If no pattern matches, return empty list
    return players;
  }

  /// Parse version string from the 'version' command response
  static String _parseVersion(String response) {
    final cleaned = _parseRconResponse(response);

    // Extract version from response like "This server is running Minecraft version 1.20.4"
    final match = RegExp(r'Minecraft version ([\d.]+)').firstMatch(cleaned);
    if (match != null) {
      return match.group(1)!;
    }

    // Return cleaned response if pattern doesn't match
    return cleaned;
  }

  /// Parse an RCON response and extract useful information
  static String _parseRconResponse(String rawResponse) {
    // Remove common prefixes and formatting
    var cleaned = rawResponse.trim();

    // Remove color codes (§ followed by hex digit)
    cleaned = cleaned.replaceAll(RegExp(r'§[0-9a-fk-or]'), '');

    // Remove ANSI escape codes
    cleaned = cleaned.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');

    return cleaned;
  }
}

/// Extension methods on [RconClient] for common Minecraft operations
extension RconClientExtension on RconClient {
  /// Get full server information including players and version
  ///
  /// Executes 'list' and 'version' commands and returns a [MinecraftServerInfo]
  /// object with parsed data.
  ///
  /// Example:
  /// ```dart
  /// final client = await connectToRcon('localhost', 25575, 'password');
  /// final info = await client.getServerInfo();
  /// print('Version: ${info.version}');
  /// print('Players: ${info.players}');
  /// await client.close();
  /// ```
  Future<MinecraftServerInfo> getServerInfo() async {
    final playersRaw = await sendCommand('list');
    final versionRaw = await sendCommand('version');
    return MinecraftServerInfo.fromRawResponses(playersRaw, versionRaw);
  }

  /// Get the server version
  ///
  /// Executes the 'version' command and returns the parsed version string.
  ///
  /// Example:
  /// ```dart
  /// final client = await connectToRcon('localhost', 25575, 'password');
  /// final version = await client.getServerVersion();
  /// print('Server version: $version');
  /// await client.close();
  /// ```
  Future<String> getServerVersion() async {
    final response = await sendCommand('version');
    return MinecraftServerInfo._parseVersion(response);
  }

  /// List all online players
  ///
  /// Executes the 'list' command and returns a list of player names.
  ///
  /// Example:
  /// ```dart
  /// final client = await connectToRcon('localhost', 25575, 'password');
  /// final players = await client.listPlayers();
  /// print('Online players: $players');
  /// await client.close();
  /// ```
  Future<List<String>> listPlayers() async {
    final response = await sendCommand('list');
    return MinecraftServerInfo._parsePlayerList(response);
  }
}

/// Connect to an RCON server with the given credentials
///
/// This is a convenience function that creates an [RconClient], connects,
/// authenticates, and returns the authenticated client.
///
/// Example:
/// ```dart
/// final client = await connectToRcon('localhost', 25575, 'password');
/// final info = await client.getServerInfo();
/// await client.close();
/// ```
Future<RconClient> connectToRcon(String host, int port, String password, {Duration? timeout}) async {
  final client = RconClient(host, port, password, timeout: timeout ?? defaultRconTimeout);

  await client.connect();
  await client.authenticate();

  return client;
}
