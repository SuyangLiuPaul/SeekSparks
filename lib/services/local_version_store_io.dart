/// The native half of bwh47's store — see `local_version_store.dart`.
///
/// A no-op, and deliberately not a `path_provider` implementation. The
/// import surface is web-only (like the offline-pack UI), so a native
/// build never reaches these; writing a file-system store nothing calls
/// would be code that cannot be exercised, which is how a store comes to
/// be wrong without anyone finding out.
library;

class LocalVersionStore {
  LocalVersionStore._();

  static bool get isAvailable => false;

  static Future<List<String>> listCodes() async => const <String>[];

  static Future<String?> read(String code) async => null;

  static Future<bool> write(String code, String label, String json) async =>
      false;

  static Future<Map<String, String>> labels() async => const <String, String>{};

  static Future<void> delete(String code) async {}
}
