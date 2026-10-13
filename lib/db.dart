import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'cloud_config.dart';

/// Database layer: Hive (local cache, works offline) + Supabase (shared cloud database).
///
/// Every "table" is a Hive box. A row is stored as   id -> JSON text.
/// All tables except `meta` (per-device settings / login session) are mirrored to ONE cloud table
/// `records(tbl, id, data)`. Writes go to Hive first, then are pushed to the cloud in the background.
/// Every few seconds the app pulls changes made by other devices and refreshes the UI.
class Db {
  static const tables = [
    'users',
    'hospitals',
    'doctors',
    'appointments',
    'ambulances',
    'ambulanceRequests',
    'bloodRequests',
    'donors',
    'bloodStock',
    'notifications',
    'meta',
  ];
  static final _cloudTables = tables.where((t) => t != 'meta').toList();

  static final Map<String, Box<String>> _boxes = {};

  /// Called after another device changed data (the store reloads and refreshes the UI).
  static VoidCallback? onRemoteChange;

  static bool get cloudEnabled => kSupabaseUrl.isNotEmpty && kSupabaseKey.isNotEmpty;

  static Future<void> init() async {
    await Hive.initFlutter();
    for (final t in tables) {
      _boxes[t] = await Hive.openBox<String>('hms_$t');
    }
    if (!cloudEnabled) return;
    try {
      final rows = await _fetchAll();
      final cloudEmpty = rows.values.every((m) => m.isEmpty);
      if (cloudEmpty) {
        // First device ever: upload whatever exists locally.
        for (final t in _cloudTables) {
          for (final k in _b(t).keys.cast<String>()) {
            _queue(t, k, _b(t).get(k));
          }
        }
        await _flush();
      } else {
        await _applyRemote(rows);
      }
    } catch (e) {
      debugPrint('Cloud init failed (working offline): $e');
    }
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _tick());
  }

  static Box<String> _b(String table) => _boxes[table]!;

  /// True on the very first launch (nothing saved locally or in the cloud) -> the app seeds sample data.
  static bool get isFirstRun => _b('hospitals').isEmpty;

  /// Reads every row of a table.
  static List<Map<String, dynamic>> all(String table) =>
      _b(table).values.map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map)).toList();

  /// Makes the table match [rows] exactly: inserts/updates changed rows, deletes removed rows.
  /// Each row must contain an 'id'. Cloud upload happens in the background.
  static Future<void> sync(String table, Iterable<Map<String, dynamic>> rows) async {
    final box = _b(table);
    final next = <String, String>{for (final r in rows) r['id'] as String: jsonEncode(r)};
    final stale = box.keys.cast<String>().where((k) => !next.containsKey(k)).toList();
    final changed = <String, String>{};
    next.forEach((k, v) {
      final old = box.get(k);
      if (old == null || _sig(old) != _sig(v)) changed[k] = v;
    });
    if (stale.isEmpty && changed.isEmpty) return;
    _version++;
    if (stale.isNotEmpty) await box.deleteAll(stale);
    if (changed.isNotEmpty) await box.putAll(changed);
    if (table != 'meta') {
      for (final k in stale) {
        _queue(table, k, null);
      }
      changed.forEach((k, v) => _queue(table, k, v));
      unawaited(_flush());
    }
  }

  // ---- small key/value settings (dark mode, admin PIN, login session ...) : local only ----
  static String? getMeta(String key) => _b('meta').get(key);
  static Future<void> setMeta(String key, String value) => _b('meta').put(key, value);
  static Future<void> deleteMeta(String key) => _b('meta').delete(key);

  // =====================================================================
  // Cloud sync internals
  // =====================================================================
  static Timer? _timer;
  static bool _ticking = false;
  static bool _flushing = false;
  static int _version = 0; // bumps on every local change

  /// table -> id -> json (null means "delete in the cloud"). Kept until the cloud confirms.
  static final Map<String, Map<String, String?>> _pending = {};

  static void _queue(String table, String id, String? json) {
    _pending.putIfAbsent(table, () => {})[id] = json;
  }

  static String get _base => kSupabaseUrl.endsWith('/') ? kSupabaseUrl.substring(0, kSupabaseUrl.length - 1) : kSupabaseUrl;

  static Map<String, String> get _headers => {
        'apikey': kSupabaseKey,
        if (kSupabaseKey.startsWith('eyJ')) 'Authorization': 'Bearer $kSupabaseKey',
        'Content-Type': 'application/json',
      };

  static Uri _uri([Map<String, String>? q]) => Uri.parse('$_base/rest/v1/records').replace(queryParameters: q);

  /// Pushes pending changes. Returns true when everything was uploaded.
  static Future<bool> _flush() async {
    if (!cloudEnabled) return true;
    if (_flushing) return false;
    _flushing = true;
    try {
      while (_pending.isNotEmpty) {
        final snap = <String, Map<String, String?>>{for (final e in _pending.entries) e.key: Map.of(e.value)};
        final upserts = <Map<String, dynamic>>[];
        final deletes = <String, List<String>>{};
        snap.forEach((t, m) {
          m.forEach((id, json) {
            if (json == null) {
              deletes.putIfAbsent(t, () => []).add(id);
            } else {
              upserts.add({'tbl': t, 'id': id, 'data': jsonDecode(json)});
            }
          });
        });
        for (var i = 0; i < upserts.length; i += 100) {
          final chunk = upserts.sublist(i, i + 100 > upserts.length ? upserts.length : i + 100);
          final res = await http
              .post(_uri({'on_conflict': 'tbl,id'}),
                  headers: {..._headers, 'Prefer': 'resolution=merge-duplicates,return=minimal'}, body: jsonEncode(chunk))
              .timeout(const Duration(seconds: 20));
          if (res.statusCode >= 300) throw Exception('POST ${res.statusCode}: ${res.body}');
        }
        for (final e in deletes.entries) {
          for (var i = 0; i < e.value.length; i += 50) {
            final ids = e.value.sublist(i, i + 50 > e.value.length ? e.value.length : i + 50);
            final res = await http
                .delete(_uri({'tbl': 'eq.${e.key}', 'id': 'in.(${ids.map((x) => '"$x"').join(',')})'}), headers: _headers)
                .timeout(const Duration(seconds: 20));
            if (res.statusCode >= 300) throw Exception('DELETE ${res.statusCode}: ${res.body}');
          }
        }
        // Forget only what was uploaded and not changed again meanwhile.
        snap.forEach((t, m) {
          m.forEach((id, json) {
            final cur = _pending[t];
            if (cur != null && cur.containsKey(id) && cur[id] == json) cur.remove(id);
          });
        });
        _pending.removeWhere((_, m) => m.isEmpty);
      }
      return true;
    } catch (e) {
      debugPrint('Cloud push failed (will retry): $e');
      return false;
    } finally {
      _flushing = false;
    }
  }

  static Future<void> _tick() async {
    if (_ticking) return;
    _ticking = true;
    try {
      if (_pending.isNotEmpty) {
        await _flush();
        if (_pending.isNotEmpty) return; // never pull while local changes are waiting to upload
      }
      final v = _version;
      final rows = await _fetchAll();
      if (v != _version || _pending.isNotEmpty) return; // local data changed during the download
      if (await _applyRemote(rows)) onRemoteChange?.call();
    } catch (e) {
      debugPrint('Cloud pull failed (offline?): $e');
    } finally {
      _ticking = false;
    }
  }

  /// Downloads every cloud row: table -> id -> json.
  static Future<Map<String, Map<String, String>>> _fetchAll() async {
    final out = <String, Map<String, String>>{for (final t in _cloudTables) t: <String, String>{}};
    const page = 1000;
    var offset = 0;
    while (true) {
      final res = await http
          .get(_uri({'select': 'tbl,id,data', 'order': 'tbl,id', 'limit': '$page', 'offset': '$offset'}), headers: _headers)
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('GET ${res.statusCode}: ${res.body}');
      final list = jsonDecode(res.body) as List;
      for (final r in list) {
        final t = r['tbl'] as String;
        if (out.containsKey(t)) out[t]![r['id'] as String] = jsonEncode(r['data']);
      }
      if (list.length < page) break;
      offset += page;
    }
    return out;
  }

  /// Makes local boxes equal to the cloud. Returns true if anything changed.
  static Future<bool> _applyRemote(Map<String, Map<String, String>> rows) async {
    var changed = false;
    for (final t in _cloudTables) {
      final box = _b(t);
      final remote = rows[t] ?? const <String, String>{};
      final puts = <String, String>{};
      remote.forEach((id, json) {
        final old = box.get(id);
        if (old == null || _sig(old) != _sig(json)) puts[id] = json;
      });
      final gone = box.keys.cast<String>().where((k) => !remote.containsKey(k)).toList();
      if (puts.isNotEmpty) await box.putAll(puts);
      if (gone.isNotEmpty) await box.deleteAll(gone);
      if (puts.isNotEmpty || gone.isNotEmpty) changed = true;
    }
    return changed;
  }

  /// Order-independent signature so the same data never looks "changed" just because key order differs.
  static String _sig(String json) => jsonEncode(_norm(jsonDecode(json)));

  static dynamic _norm(dynamic v) {
    if (v is Map) {
      final keys = v.keys.map((k) => k.toString()).toList()..sort();
      return {for (final k in keys) k: _norm(v[k])};
    }
    if (v is List) return v.map(_norm).toList();
    if (v is double && v.isFinite && v == v.truncateToDouble()) return v.toInt();
    return v;
  }
}
