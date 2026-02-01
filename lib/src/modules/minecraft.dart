import 'package:dart_minecraft/dart_minecraft.dart';
import 'package:dart_minecraft/src/packet/packets/response_packet.dart';

Future<ResponsePacket?> pingServer(String serverUri) async {
  return ping(serverUri, timeout: Duration(seconds: 5));
}
