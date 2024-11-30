import 'dart:async';
import 'dart:io';

import 'package:nyxx/nyxx.dart';
import 'package:shelf_session/session_middleware.dart';

const sessionsFile = '/sessions/sessions.json';

class SessionManagerPlugin extends NyxxPlugin<NyxxGateway> {
  Future<void> triggerSaveSessions() async {
    await saveSessions((sessionData) async {
      logger.info("Saving session file");
      await File(sessionsFile).writeAsString(sessionData);
    });
  }

  @override
  FutureOr<void> afterConnect(NyxxGateway client) async {
    await restoreSessions(() async {
      final file = File(sessionsFile);
      if (await file.exists()) {
        logger.info("Loading session file.");
        return File(sessionsFile).readAsString();
      }

      logger.info("Session file missing. Returning default");
      return '{}';
    });

    Timer.periodic(Duration(minutes: 15), (timer) => triggerSaveSessions());
  }

  @override
  FutureOr<void> afterClose() async {
    triggerSaveSessions();
  }
}
