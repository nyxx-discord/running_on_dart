import 'dart:async';
import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:shelf_session/session_middleware.dart';

class SessionManagerPlugin extends NyxxPlugin<NyxxGateway> {
  static const _sessionsFile = '/sessions/sessions.json';

  void _saveSessions() async {
    await saveSessions((sessionData) async {
      logger.info("Saving session file");
      await File(_sessionsFile).writeAsString(sessionData);
    });
  }

  @override
  FutureOr<void> afterConnect(NyxxGateway client) async {
    await restoreSessions(() async {
      final file = File(_sessionsFile);
      if (await file.exists()) {
        logger.info("Loading session file.");
        return File(_sessionsFile).readAsString();
      }

      logger.info("Session file missing. Returning default");
      return '{}';
    });

    Timer.periodic(Duration(minutes: 15), (timer) => _saveSessions());
  }

  @override
  FutureOr<void> afterClose() async {
    _saveSessions();
  }
}
