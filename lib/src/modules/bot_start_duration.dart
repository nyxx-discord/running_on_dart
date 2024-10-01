class BotStartDuration {
  static BotStartDuration get instance =>
      _instance ?? (throw Exception('BotStartDuration must be initialised with BotStartDuration.init()'));
  static BotStartDuration? _instance;

  static void init() {
    _instance = BotStartDuration._();
  }

  late final DateTime startDate;

  BotStartDuration._() {
    startDate = DateTime.now();
  }
}
