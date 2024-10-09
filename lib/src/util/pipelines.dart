import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/util/util.dart';

typedef TargetMessageSupplier = Future<Message> Function(MessageBuilder);
typedef TargetUpdateMessageSupplier = Future<Message> Function(MessageUpdateBuilder);
typedef MessageSupplier = Future<Message> Function();

typedef UpdateCallback = Future<(bool, String?)> Function();
typedef RunCallback = Future<void> Function();

EmbedBuilder getInitialEmbed(int taskAmount) =>
    EmbedBuilder(title: 'Task 1 of $taskAmount', description: 'Starting...');

class Task {
  final UpdateCallback updateCallback;
  final RunCallback runCallback;

  const Task({required this.runCallback, required this.updateCallback});
}

class InternalTask {
  final UpdateCallback updateCallback;
  final Duration updateInterval;
  final Message targetMessage;

  const InternalTask({required this.targetMessage, required this.updateCallback, required this.updateInterval});

  Future<void> execute(EmbedBuilder embed) async {
    final completer = Completer();

    Timer.periodic(updateInterval, (timer) async {
      final (finished, currentStatus) = await updateCallback();

      embed.description = currentStatus.toString();
      await targetMessage.update(MessageUpdateBuilder(embeds: [embed]));

      if (finished) {
        completer.complete();
        timer.cancel();
      }
    });

    return completer.future;
  }
}

class Pipeline {
  final List<Task> tasks;
  final MessageSupplier messageSupplier;
  final Duration updateInterval;

  late EmbedBuilder embed;

  Pipeline({required this.messageSupplier, required this.tasks, required this.updateInterval, required this.embed});

  factory Pipeline.fromCreateContext(
      {required TargetMessageSupplier messageSupplier, required List<Task> tasks, required Duration updateInterval}) {
    final embed = getInitialEmbed(tasks.length);

    return Pipeline(
        messageSupplier: () => messageSupplier(MessageBuilder(embeds: [embed], components: [], content: null)),
        tasks: tasks,
        updateInterval: updateInterval,
        embed: embed);
  }

  factory Pipeline.fromUpdateContext(
      {required TargetUpdateMessageSupplier messageSupplier,
      required List<Task> tasks,
      required Duration updateInterval}) {
    final embed = getInitialEmbed(tasks.length);

    return Pipeline(
      messageSupplier: () => messageSupplier(MessageUpdateBuilder(embeds: [embed], components: [], content: null)),
      tasks: tasks,
      updateInterval: updateInterval,
      embed: embed,
    );
  }

  Future<void> execute() async {
    final message = await messageSupplier();

    final timer = Stopwatch()..start();
    for (final task in tasks) {
      final internalTask =
          InternalTask(targetMessage: message, updateCallback: task.updateCallback, updateInterval: updateInterval);

      task.runCallback();
      await internalTask.execute(embed);
    }

    embed.description = 'Done! Took ${timer.elapsed.formatShort()}';

    message.update(MessageUpdateBuilder(embeds: [embed]));
  }
}
