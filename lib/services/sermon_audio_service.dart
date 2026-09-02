import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// One audio file: a sermon, or one part of one.
///
/// The church publishes long sermons in lettered parts — `002a`, `002b`
/// — as separate files, so a "sermon" is a LIST of these, in order.
/// Joining them into one stream is not possible without re-encoding
/// four and a half gigabytes we do not host, so the player moves
/// between them instead and says which part is playing.
@immutable
class SermonAudioPart {
  const SermonAudioPart({
    required this.part,
    required this.path,
    required this.bytes,
  });

  /// The part letter as the church names it: `a`, `b`, … A sermon in
  /// one file still has one, because `index.json`'s own `parts` field
  /// names it and the two are checked against each other.
  final String part;

  /// The path under the base host. Stored WITHOUT the host so that the
  /// host can move — see [SermonAudioService.base].
  final String path;

  /// Content-Length as surveyed. Shown to a reader before they spend
  /// their data on it, and the only honest size we have: the host sends
  /// no duration, and `fetch` cannot ask on web because these URLs
  /// carry no `Access-Control-Allow-Origin`.
  final int bytes;

  static SermonAudioPart fromJson(Map<String, dynamic> j) => SermonAudioPart(
        part: (j['p'] as String?) ?? '',
        path: j['u'] as String,
        bytes: (j['b'] as num?)?.toInt() ?? 0,
      );
}

/// Where each sermon's audio lives.
///
/// THE APP SHIPS PATHS, NOT AUDIO. The 589 recordings are 4.88 GB and
/// have been public on the church's own site since a single upload on
/// 2022-01-09; mirroring them would be four and a half gigabytes of
/// hosting to serve files that are already served. What ships is
/// `assets/sermons/audio.json`, 107 KB of paths.
///
/// WHY THE HOST IS A DART-DEFINE. Someone else's nginx is the one risk
/// in this arrangement that we cannot manage: a Drupal upgrade or a
/// tidy-up renames every path at once, and hotlink-blocking could be
/// turned on any day. `--dart-define=SERMON_AUDIO_BASE=...` means
/// moving to a mirror is a rebuild rather than an edit to 589 rows, and
/// the manifest is regenerable from the church's index page in minutes.
///
/// WHAT WORKS WHERE. The host sends no `Access-Control-Allow-Origin`.
/// A media element — which is what `just_audio` compiles to on web — is
/// not subject to CORS unless it sets `crossOrigin`, so PLAYBACK works
/// everywhere. `fetch`/XHR against these URLs does not, which is why
/// audio cannot join the web offline pack the way the other categories
/// do, and why native can download and web can only stream. The UI says
/// so rather than failing quietly.
class SermonAudioService {
  SermonAudioService._();
  static final SermonAudioService instance = SermonAudioService._();

  /// The host, overridable at build time. The default is the church's
  /// own site, which is where the files actually are.
  static const String base = String.fromEnvironment(
    'SERMON_AUDIO_BASE',
    defaultValue: 'https://www.christiandiscipleschurch.org',
  );

  Map<String, List<SermonAudioPart>>? _cache;

  Map<String, List<SermonAudioPart>>? get cached => _cache;

  Future<Map<String, List<SermonAudioPart>>> load() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/sermons/audio.json');
    final j = json.decode(raw) as Map<String, dynamic>;
    final audio = (j['audio'] as Map<String, dynamic>?) ?? const {};
    final out = <String, List<SermonAudioPart>>{};
    for (final entry in audio.entries) {
      final parts = (entry.value as List)
          .whereType<Map<String, dynamic>>()
          .map(SermonAudioPart.fromJson)
          .toList();
      if (parts.isNotEmpty) out[entry.key] = parts;
    }
    return _cache = out;
  }

  /// The parts for one sermon, empty when it has no audio.
  ///
  /// Empty is a real answer and the UI must handle it: the church
  /// publishes transcripts for messages it has no recording of, so a
  /// sermon with no audio is a normal state and not a failure.
  List<SermonAudioPart> partsFor(String sermonId) =>
      _cache?[sermonId] ?? const [];

  /// The absolute URL for a part.
  ///
  /// Joined here rather than stored, so [base] is the only thing that
  /// has to change when the host does.
  static String urlFor(SermonAudioPart part) {
    final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final p = part.path.startsWith('/') ? part.path : '/${part.path}';
    return '$b$p';
  }

  /// A human size for a part, so a reader on mobile data can decide
  /// before tapping. Deliberately coarse — the exact byte count is in
  /// the manifest and means nothing to a listener.
  static String sizeLabel(int bytes) {
    if (bytes <= 0) return '';
    final mb = bytes / (1024 * 1024);
    return mb >= 100 ? '${mb.round()} MB' : '${mb.toStringAsFixed(1)} MB';
  }
}
