import 'package:running_on_dart/src/modules/rcon.dart';
import 'package:test/test.dart';

void main() {
  group('RconPacket', () {
    test('should create a packet with correct properties', () {
      final packet = RconPacket(requestId: 123, type: serverdataAuth, payload: 'test');

      expect(packet.size, 18); // 4 (size) + 4 (requestId) + 4 (type) + 4 (payload) + 2 (null terminators)
      expect(packet.requestId, 123);
      expect(packet.type, serverdataAuth);
      expect(packet.payload, 'test');
    });

    test('toString should format correctly', () {
      final packet = RconPacket(requestId: 123, type: serverdataAuth, payload: 'test');

      final str = packet.toString();
      expect(str, contains('size: 18'));
      expect(str, contains('requestId: 123'));
      expect(str, contains('type: 3'));
      expect(str, contains('payload: "test"'));
    });
  });

  group('RconException', () {
    test('should create exception with message', () {
      final exception = RconException('Test error');
      expect(exception.message, 'Test error');
      expect(exception.originalError, isNull);
      expect(exception.toString(), 'RconException: Test error');
    });

    test('should create exception with message and original error', () {
      final original = Exception('Original error');
      final exception = RconException('Test error', original);
      expect(exception.message, 'Test error');
      expect(exception.originalError, original);
      expect(exception.toString(), contains('Test error'));
      expect(exception.toString(), contains('Original error'));
    });

    test('RconAuthenticationException should extend RconException', () {
      final exception = RconAuthenticationException();
      expect(exception, isA<RconException>());
      expect(exception.message, 'RCON authentication failed');
    });

    test('RconConnectionException should extend RconException', () {
      final exception = RconConnectionException();
      expect(exception, isA<RconException>());
      expect(exception.message, 'Failed to connect to RCON server');
    });

    test('RconTimeoutException should extend RconException', () {
      final exception = RconTimeoutException();
      expect(exception, isA<RconException>());
      expect(exception.message, 'RCON operation timed out');
    });

    test('RconProtocolException should extend RconException', () {
      final exception = RconProtocolException();
      expect(exception, isA<RconException>());
      expect(exception.message, 'RCON protocol violation');
    });
  });

  group('RconClient', () {
    late RconClient client;

    setUp(() {
      client = RconClient('localhost', 25575, 'password', timeout: const Duration(seconds: 2));
    });

    tearDown(() async {
      if (client.isConnected) {
        await client.close();
      }
    });

    test('should create client with correct properties', () {
      expect(client.host, 'localhost');
      expect(client.port, 25575);
      expect(client.password, 'password');
      expect(client.timeout, const Duration(seconds: 2));
      expect(client.isConnected, isFalse);
      expect(client.isAuthenticated, isFalse);
    });

    test('should throw when trying to authenticate without connection', () async {
      expect(() => client.authenticate(), throwsA(isA<RconConnectionException>()));
    });

    test('should throw when trying to send command without connection', () async {
      expect(() => client.sendCommand('test'), throwsA(isA<RconConnectionException>()));
    });
  });

  group('MinecraftServerInfo', () {
    test('should create server info from raw responses', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'There are 3 of a max of 20 players online: Steve, Alex, Notch',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.playersRaw, contains('There are 3 of a max of 20 players online'));
      expect(info.versionRaw, contains('Minecraft version 1.20.4'));
      expect(info.players, ['Steve', 'Alex', 'Notch']);
      expect(info.version, '1.20.4');
    });

    test('should parse player list from standard format', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'There are 3 of a max of 20 players online: Steve, Alex, Notch',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.players, ['Steve', 'Alex', 'Notch']);
    });

    test('should parse player list from bracket format', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'players: (3) [Steve, Alex, Notch]',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.players, ['Steve', 'Alex', 'Notch']);
    });

    test('should parse version from response', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'There are 0 of a max of 20 players online: ',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.version, '1.20.4');
    });

    test('should handle empty player list', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'There are 0 of a max of 20 players online: ',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.players, isEmpty);
    });

    test('should handle color codes in response', () {
      final info = MinecraftServerInfo.fromRawResponses(
        '§6There are 2 of a max of 20 players online: §eSteve§f, §aAlex',
        'This server is running Minecraft version 1.20.4',
      );

      expect(info.players, ['Steve', 'Alex']);
    });

    test('toString should format correctly', () {
      final info = MinecraftServerInfo.fromRawResponses(
        'There are 1 of a max of 20 players online: Steve',
        'This server is running Minecraft version 1.20.4',
      );

      final str = info.toString();
      expect(str, contains('version: "1.20.4"'));
      expect(str, contains('players: [Steve]'));
    });
  });

  group('Constants', () {
    test('serverdataAuth should be 3', () {
      expect(serverdataAuth, 3);
    });

    test('serverdataAuthResponse should be 2', () {
      expect(serverdataAuthResponse, 2);
    });

    test('serverdataExecCommand should be 2', () {
      expect(serverdataExecCommand, 2);
    });

    test('serverdataResponseValue should be 0', () {
      expect(serverdataResponseValue, 0);
    });

    test('defaultRconPort should be 25575', () {
      expect(defaultRconPort, 25575);
    });

    test('defaultRconTimeout should be 5 seconds', () {
      expect(defaultRconTimeout, const Duration(seconds: 5));
    });
  });

  group('Integration-style tests (without actual server)', () {
    test('connectToRcon should throw on connection failure', () async {
      // This will fail because there's no RCON server running
      expect(
        () => connectToRcon('localhost', 25575, 'wrongpassword', timeout: const Duration(seconds: 1)),
        throwsA(isA<RconException>()),
      );
    });
  });
}
