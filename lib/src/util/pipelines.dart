import 'dart:async';

import 'package:nyxx/nyxx.dart';
import 'package:running_on_dart/src/util/util.dart';

typedef TargetMessageSupplier = Future<Message> Function(MessageBuilder);
typedef TargetUpdateMessageSupplier = Future<Message> Function(MessageUpdateBuilder);
typedef MessageSupplier = Future<Message> Function();

typedef UpdateCallback = Future<(bool, String?)> Function();
typedef RunCallback = Future<void> Function();

EmbedBuilder getInitialEmbed(int taskAmount, String pipelineName) => EmbedBuilder(
    title: getEmbedTitle(1, taskAmount),
    description: 'Starting...',
    author: EmbedAuthorBuilder(name: "Pipeline `$pipelineName`"));

String getEmbedTitle(int index, int length) => 'Task $index of $length';

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

      embed.description = currentStatus ?? '...';
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
  final String name;
  final String description;
  final List<Task> tasks;
  final Duration updateInterval;

  Pipeline({required this.name, required this.description, required this.tasks, required this.updateInterval});

  InternalPipeline forCreateContext({required TargetMessageSupplier messageSupplier}) {
    final embed = getInitialEmbed(tasks.length, name);

    return InternalPipeline(
        messageSupplier: () => messageSupplier(MessageBuilder(embeds: [embed], components: [], content: null)),
        tasks: tasks,
        updateInterval: updateInterval,
        embed: embed);
  }

  InternalPipeline forUpdateContext({required TargetUpdateMessageSupplier messageSupplier}) {
    final embed = getInitialEmbed(tasks.length, name);

    return InternalPipeline(
      messageSupplier: () => messageSupplier(MessageUpdateBuilder(embeds: [embed], components: [], content: null)),
      tasks: tasks,
      updateInterval: updateInterval,
      embed: embed,
    );
  }
}

class InternalPipeline {
  final List<Task> tasks;
  final MessageSupplier messageSupplier;
  final Duration updateInterval;

  late EmbedBuilder embed;

  InternalPipeline(
      {required this.messageSupplier, required this.tasks, required this.updateInterval, required this.embed});

  Future<void> execute() async {
    final message = await messageSupplier();

    final timer = Stopwatch()..start();
    for (final (index, task) in tasks.indexed) {
      final internalTask =
          InternalTask(targetMessage: message, updateCallback: task.updateCallback, updateInterval: updateInterval);

      embed.title = getEmbedTitle(index + 1, tasks.length);
      task.runCallback();
      await internalTask.execute(embed);
    }

    embed.description = 'Done! Took ${timer.elapsed.formatShort()}';

    message.update(MessageUpdateBuilder(embeds: [embed]));
  }
}
