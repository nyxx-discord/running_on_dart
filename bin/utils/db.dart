import "package:sembast/sembast.dart";
import "package:sembast/sembast_io.dart";

typedef DefaultStore = StoreRef<String, Map<String, Object?>>;

class RodDb {
  static const _dbpath = "database.db";
  static const _channelStore = "channels";

  static TagStore get tagStore => TagStore._new();
  static ChannelStore get channelStore => ChannelStore._new();

  static Database? _database;

  static Future<Database> openDatabase() async {
    _database ??= await databaseFactoryIo.openDatabase(_dbpath);

    return _database!;
  }
}

abstract class RodStore {
  String get _storeName;

  late final DefaultStore _store;

  RodStore._new() {
    this._store = stringMapStoreFactory.store(_storeName);
  }
}

class TagStore extends RodStore {
  @override
  String get _storeName => "tags";

  TagStore._new() : super._new();

  Future<String?> insert(String name, String value) =>
      this._store.record(name).add(RodDb._database!, {"value": value});

  Future<String?> matchInString(String content) async {
    final result = await this._store.findFirst(RodDb._database!, finder: Finder(filter: Filter.custom((RecordSnapshot<dynamic, dynamic> record) => content.contains(record.key.toString()))));

    if (result == null) {
      return null;
    }

    return result["value"].toString();
  }

  Future<String?> getByName(String name) async {
    final result = await this._store.findFirst(RodDb._database!, finder: Finder(filter: Filter.byKey(name)));

    if (result == null) {
      return null;
    }

    return result["value"].toString();
  }
}

class ChannelStore extends RodStore {
  @override
  String get _storeName => "channels";

  ChannelStore._new() : super._new();

  Future<String> insert(String channelId) =>
      this._store.add(RodDb._database!, {
        "channel_id": channelId,
      });

  Future<bool> hasEnabledTags(String channelId) async {
    final result = await this._store.findFirst(RodDb._database!, finder: Finder(filter: Filter.equals("channel_id", channelId)));
    return result != null;
  }
}
