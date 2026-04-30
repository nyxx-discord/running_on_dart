import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

// RCON Packet Types (Source RCON Protocol)
const int serverdataAuth = 3;
const int serverdataAuthResponse = 2;
const int serverdataExecCommand = 2;
const int serverdataResponseValue = 0;

// Default RCON port
const int defaultRconPort = 25575;

// Default timeout duration
const Duration defaultRconTimeout = Duration(seconds: 5);

/// Base exception class for all RCON-related errors
class RconException implements Exception {
  final String message;
  final dynamic originalError;

  RconException(this.message, [this.originalError]);

  @override
  String toString() => 'RconException: $message${originalError != null ? ' (caused by: $originalError)' : ''}';
}

/// Exception thrown when RCON authentication fails
class RconAuthenticationException extends RconException {
  RconAuthenticationException([super.message = 'RCON authentication failed', super.originalError]);
}

/// Exception thrown when RCON connection fails
class RconConnectionException extends RconException {
  RconConnectionException([super.message = 'Failed to connect to RCON server', super.originalError]);
}

/// Exception thrown when RCON operation times out
class RconTimeoutException extends RconException {
  RconTimeoutException([super.message = 'RCON operation timed out', super.originalError]);
}

/// Exception thrown when RCON protocol violation occurs
class RconProtocolException extends RconException {
  RconProtocolException([super.message = 'RCON protocol violation', super.originalError]);
}

/// Represents an RCON packet
class RconPacket {
  final int size;
  final int requestId;
  final int type;
  final String payload;

  RconPacket({required this.requestId, required this.type, required this.payload})
    : size = 4 + 4 + 4 + payload.length + 2; // size + requestId + type + payload + 2 null terminators

  @override
  String toString() => 'RconPacket(size: $size, requestId: $requestId, type: $type, payload: "$payload")';
}

/// RCON client for communicating with Minecraft servers
class RconClient {
  final String host;
  final int port;
  final String password;
  final Duration timeout;

  Socket? _socket;
  int _requestId = 0;
  bool _isAuthenticated = false;

  /// Creates a new RCON client
  RconClient(this.host, this.port, this.password, {this.timeout = defaultRconTimeout});

  /// Check if the client is connected
  bool get isConnected => _socket != null;

  /// Check if the client is authenticated
  bool get isAuthenticated => _isAuthenticated;

  /// Connect to the RCON server
  Future<void> connect() async {
    if (isConnected) {
      throw RconConnectionException('Already connected to RCON server');
    }

    try {
      _socket = await Socket.connect(host, port, timeout: timeout);
    } on SocketException catch (e) {
      throw RconConnectionException('Failed to connect to $host:$port', e);
    } on TimeoutException catch (e) {
      throw RconTimeoutException('Connection to $host:$port timed out', e);
    }
  }

  /// Authenticate with the RCON server
  Future<void> authenticate() async {
    if (!isConnected) {
      throw RconConnectionException('Not connected to RCON server');
    }

    if (_isAuthenticated) {
      return;
    }

    final requestId = _nextRequestId();
    final authPacket = RconPacket(requestId: requestId, type: serverdataAuth, payload: password);

    await _sendPacket(authPacket);

    final responses = await _readPackets();

    bool authSuccess = false;
    for (final response in responses) {
      if (response.requestId == -1) {
        throw RconAuthenticationException('Invalid RCON password');
      }
      if (response.requestId == requestId && response.type == serverdataAuthResponse) {
        authSuccess = true;
      }
    }

    if (!authSuccess) {
      throw RconAuthenticationException('Authentication failed - no valid response received');
    }

    _isAuthenticated = true;
  }

  /// Send a command to the RCON server and return the response
  Future<String> sendCommand(String command) async {
    if (!isConnected) {
      throw RconConnectionException('Not connected to RCON server');
    }

    if (!_isAuthenticated) {
      throw RconAuthenticationException('Not authenticated. Call authenticate() first.');
    }

    final requestId = _nextRequestId();
    final commandPacket = RconPacket(requestId: requestId, type: serverdataExecCommand, payload: command);

    await _sendPacket(commandPacket);

    final responses = await _readPackets();

    final buffer = StringBuffer();
    for (final response in responses) {
      if (response.requestId == requestId && response.type == serverdataResponseValue) {
        buffer.write(response.payload);
      }
    }

    return buffer.toString();
  }

  /// Close the connection to the RCON server
  Future<void> close() async {
    _socket?.close();
    _socket = null;
    _isAuthenticated = false;
  }

  /// Get the next request ID
  int _nextRequestId() {
    _requestId = (_requestId + 1) & 0x7FFFFFFF; // Keep it positive
    return _requestId;
  }

  /// Send a packet to the RCON server
  Future<void> _sendPacket(RconPacket packet) async {
    final socket = _socket;
    if (socket == null) {
      throw RconConnectionException('Not connected to RCON server');
    }

    final data = _encodePacket(packet);
    socket.add(data);
    await socket.flush();
  }

  /// Read one or more response packets from the RCON server
  Future<List<RconPacket>> _readPackets() async {
    final socket = _socket;
    if (socket == null) {
      throw RconConnectionException('Not connected to RCON server');
    }

    final packets = <RconPacket>[];

    try {
      final firstPacket = await _readPacket(socket);
      packets.add(firstPacket);

      // Some servers send multiple packets for a single response
      // Continue reading until we get an empty response or timeout
      while (true) {
        RconPacket? nextPacket;
        try {
          nextPacket = await _readPacket(socket, expectEmpty: true).timeout(const Duration(milliseconds: 100));
        } on TimeoutException {
          break;
        }

        if (nextPacket.payload.isEmpty) {
          break;
        }

        packets.add(nextPacket);
      }
    } on TimeoutException {
      // If we timeout, return what we have
    }

    return packets;
  }

  /// Read a single packet from the socket
  Future<RconPacket> _readPacket(Socket socket, {bool expectEmpty = false}) async {
    final sizeBytes = await _readBytes(socket, 4);
    final size = ByteData.sublistView(Uint8List.fromList(sizeBytes)).getUint32(0, Endian.little);

    if (size < 10) {
      throw RconProtocolException('Invalid packet size: $size (minimum is 10)');
    }

    final remainingBytes = await _readBytes(socket, size);
    final byteData = ByteData.sublistView(Uint8List.fromList(remainingBytes));

    final requestId = byteData.getInt32(0, Endian.little);

    final type = byteData.getInt32(4, Endian.little);

    final payloadBytes = <int>[];
    for (int i = 8; i < size - 2; i++) {
      final byte = byteData.getUint8(i);
      if (byte == 0) {
        break;
      }
      payloadBytes.add(byte);
    }

    final payload = String.fromCharCodes(payloadBytes);

    return RconPacket(requestId: requestId, type: type, payload: payload);
  }

  /// Read a specific number of bytes from the socket
  Future<List<int>> _readBytes(Socket socket, int count) async {
    final buffer = <int>[];
    int bytesRead = 0;

    while (bytesRead < count) {
      final data = await socket.first.timeout(timeout);
      buffer.addAll(data);
      bytesRead += data.length;
    }

    return buffer.sublist(0, count);
  }

  /// Encode a packet to bytes
  Uint8List _encodePacket(RconPacket packet) {
    final payloadBytes = Uint8List.fromList(packet.payload.codeUnits);
    final totalSize = 4 + 4 + 4 + payloadBytes.length + 2; // size + requestId + type + payload + 2 null terminators

    final byteData = ByteData(totalSize);
    final buffer = byteData.buffer.asUint8List();

    byteData.setUint32(0, packet.size, Endian.little);
    byteData.setInt32(4, packet.requestId, Endian.little);
    byteData.setInt32(8, packet.type, Endian.little);
    buffer.setRange(12, 12 + payloadBytes.length, payloadBytes);

    buffer[12 + payloadBytes.length] = 0;
    buffer[12 + payloadBytes.length + 1] = 0;

    return buffer;
  }
}
