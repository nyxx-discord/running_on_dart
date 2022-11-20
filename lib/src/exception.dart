class CheckedBotException implements Exception {
  final String message;

  CheckedBotException(this.message);

  @override
  String toString() => "CheckedBotException: $message";
}
