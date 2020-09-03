import "dart:io" show Directory;
import "package:objectdb/objectdb.dart" show ObjectDB;

late ObjectDB db;

Future<void> openDatabase() async {
  db = ObjectDB("${Directory.current.path}/db/my.db");
  await db.open();
}

Future<void> closeDatabse() async {
  await db.tidy();
  await db.close();
}

Future<void> insertTag(String name, String content) async {
  await db.insert({ "name" : name, "content" : content });
}

Future<String?> getTag(String name) async {
  final tag = await db.find({ "name" : name });

  if(tag.isEmpty) {
    return null;
  }

  return tag.first["content"].toString();
}

Future<void> updateTag(String name, String content) async {
  await db.update({ "name" : name }, { "content" : content });
}

Future<void> deleteTag(String name) async {
  await db.remove({ "name" : name });
}