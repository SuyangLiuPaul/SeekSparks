/// The web half of bwh47's store: IndexedDB — see
/// `local_version_store.dart`.
///
/// One database, one object store, one record per imported version:
/// `{code, label, json}`. Flat on purpose. A schema that split the text
/// by book would make a partial write possible, and a Bible that is
/// half there is worse than one that failed to save.
///
/// Every operation resolves through a `Completer` on the request's own
/// `onsuccess`/`onerror`, and every one of them can fail — a browser in
/// private mode may refuse IndexedDB outright. So the API returns
/// null/false rather than throwing, and the caller tells the reader
/// plainly; an import that silently did not save is the failure this
/// whole file is arranged to avoid.
library;

import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

const String _kDb = 'seeksparks_versions';
const String _kStore = 'versions';
const int _kVersion = 1;

class LocalVersionStore {
  LocalVersionStore._();

  static bool get isAvailable => true;

  static Future<web.IDBDatabase?> _open() {
    final done = Completer<web.IDBDatabase?>();
    try {
      final req = web.window.indexedDB.open(_kDb, _kVersion);
      req.onupgradeneeded = (web.Event _) {
        final db = req.result as web.IDBDatabase;
        if (!db.objectStoreNames.contains(_kStore)) {
          db.createObjectStore(_kStore);
        }
      }.toJS;
      req.onsuccess = (web.Event _) {
        if (!done.isCompleted) done.complete(req.result as web.IDBDatabase);
      }.toJS;
      req.onerror = (web.Event _) {
        if (!done.isCompleted) done.complete(null);
      }.toJS;
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
    return done.future;
  }

  static Future<T?> _run<T>(
    String mode,
    T? Function(web.IDBObjectStore store, Completer<T?> done) body,
  ) async {
    final db = await _open();
    if (db == null) return null;
    final done = Completer<T?>();
    try {
      final tx = db.transaction(_kStore.toJS, mode);
      final store = tx.objectStore(_kStore);
      body(store, done);
    } catch (_) {
      if (!done.isCompleted) done.complete(null);
    }
    return done.future;
  }

  /// Codes of every imported version, or empty when the store is
  /// unreachable — which is indistinguishable from "none imported" and
  /// deliberately so: both mean the picker offers nothing extra.
  static Future<List<String>> listCodes() async {
    final out = await _run<List<String>>('readonly', (store, done) {
      final req = store.getAllKeys();
      req.onsuccess = (web.Event _) {
        final keys = (req.result as JSArray).toDart;
        done.complete([for (final k in keys) (k as JSString).toDart]);
      }.toJS;
      req.onerror = (web.Event _) { done.complete(null); }.toJS;
      return null;
    });
    return out ?? const <String>[];
  }

  /// The stored JSON for [code], or null.
  static Future<String?> read(String code) async {
    final rec = await _readRecord(code);
    return rec?['json'];
  }

  /// code → the name the reader gave it.
  static Future<Map<String, String>> labels() async {
    final codes = await listCodes();
    final out = <String, String>{};
    for (final c in codes) {
      final rec = await _readRecord(c);
      final label = rec?['label'];
      if (label != null) out[c] = label;
    }
    return out;
  }

  static Future<Map<String, String>?> _readRecord(String code) {
    return _run<Map<String, String>>('readonly', (store, done) {
      final req = store.get(code.toJS);
      req.onsuccess = (web.Event _) {
        final v = req.result;
        if (v == null || v.isUndefinedOrNull) {
          done.complete(null);
          return;
        }
        final obj = v as JSObject;
        String? field(String name) {
          final f = obj.getProperty(name.toJS);
          return f == null || f.isUndefinedOrNull
              ? null
              : (f as JSString).toDart;
        }

        final j = field('json');
        if (j == null) {
          done.complete(null);
          return;
        }
        done.complete({'json': j, 'label': field('label') ?? code});
      }.toJS;
      req.onerror = (web.Event _) { done.complete(null); }.toJS;
      return null;
    });
  }

  /// Returns false when nothing was written — quota, private mode, or a
  /// browser that refuses the database. NEVER true on a guess: the
  /// caller says "saved" only when the transaction said so.
  static Future<bool> write(String code, String label, String json) async {
    final ok = await _run<bool>('readwrite', (store, done) {
      final rec = JSObject()
        ..setProperty('label'.toJS, label.toJS)
        ..setProperty('json'.toJS, json.toJS);
      final req = store.put(rec, code.toJS);
      req.onsuccess = (web.Event _) { done.complete(true); }.toJS;
      req.onerror = (web.Event _) { done.complete(false); }.toJS;
      return null;
    });
    return ok ?? false;
  }

  static Future<void> delete(String code) async {
    await _run<bool>('readwrite', (store, done) {
      final req = store.delete(code.toJS);
      req.onsuccess = (web.Event _) { done.complete(true); }.toJS;
      req.onerror = (web.Event _) { done.complete(false); }.toJS;
      return null;
    });
  }
}
