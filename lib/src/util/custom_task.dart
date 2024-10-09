import 'dart:async';

import 'package:nyxx/nyxx.dart';

typedef UpdateCallback = Future<bool> Function(MessageUpdateBuilder builder);
typedef TargetMessageCallback = Future<Message> Function();

class CustomTask {
  final UpdateCallback updateCallback;

  CustomTask(
      {required TargetMessageCallback targetMessageCallback,
      required this.updateCallback,
      required Duration updateInterval}) {
    targetMessageCallback().then((message) {
      Timer.periodic(updateInterval, (timer) async {
        final builder = MessageUpdateBuilder();
        final result = await updateCallback(builder);

        await message.update(builder);

        if (result) {
          timer.cancel();
        }
      });
    });
  }
}
