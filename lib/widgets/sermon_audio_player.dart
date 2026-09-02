import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'package:seeksparks/constants/ui_strings.dart';
import 'package:seeksparks/constants/workbench_theme.dart';
import 'package:seeksparks/services/sermon_audio_service.dart';

/// The sermon recording, played from the church's own site.
///
/// NOTHING IS DOWNLOADED TO SHOW THIS. The player is built from the
/// manifest and nothing is fetched until the reader presses play, which
/// matters because these are 8–35 MB files and a page that started
/// buffering on open would spend a reader's data before they asked.
///
/// WHY IT DOES NOT LOAD A DURATION UP FRONT. The host sends no
/// `Access-Control-Allow-Origin`, so on web nothing may `fetch` these
/// URLs — only a media element may play them. A duration probe is a
/// fetch. So the size in megabytes is shown instead until playback
/// starts and the element reports a real duration, and the size is what
/// a reader deciding on mobile data actually wants anyway.
///
/// FAILURE DEGRADES TO THE TEXT. The transcript is on the same screen
/// and is the thing the reader came for; a dead host must therefore
/// cost a line of explanation, not the page. `setUrl` throwing is a
/// normal state here — someone else's nginx is one Drupal upgrade away
/// from renaming every path — so it is caught, said plainly, and the
/// player collapses to a single sentence.
/// What the one transport control should be, given the player's state.
///
/// A pure function, and pulled out of `build` because the bug it
/// encodes was invisible in a widget: the control used to fold
/// `ProcessingState.buffering` into a disabled spinner, which is right
/// before playback starts and WRONG after it — a stream re-buffers
/// while it plays, so the spinner replaced the pause button the first
/// time the network hiccuped and the reader could not stop the sermon.
/// It was reported as "there is no pause button", which is what it
/// looked like from the outside.
///
/// The rule: the spinner means "not yet playable" and nothing else.
/// Once [playing] is true the control is PAUSE and stays pause.
@visibleForTesting
({bool showPause, bool waiting}) sermonAudioControl({
  required bool playing,
  required bool preparing,
  required ProcessingState? processing,
}) {
  final waiting = !playing &&
      (preparing ||
          processing == ProcessingState.loading ||
          processing == ProcessingState.buffering);
  return (showPause: playing, waiting: waiting);
}

class SermonAudioPlayer extends StatefulWidget {
  const SermonAudioPlayer({
    super.key,
    required this.parts,
    required this.locale,
  });

  final List<SermonAudioPart> parts;
  final String locale;

  @override
  State<SermonAudioPlayer> createState() => _SermonAudioPlayerState();
}

class _SermonAudioPlayerState extends State<SermonAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();

  int _index = 0;
  bool _prepared = false;
  bool _preparing = false;
  String? _error;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  String _s(String key, String fallback) =>
      uiStrings[key]?[widget.locale] ?? sermonAudioStrings[key]?[widget.locale] ??
      fallback;

  SermonAudioPart get _part => widget.parts[_index];

  /// Point the player at [_index] and start it.
  ///
  /// The URL is set on DEMAND, not in `initState`: `setUrl` opens the
  /// connection and begins buffering, and doing that for every sermon a
  /// reader opens would download megabytes nobody asked for.
  Future<void> _play() async {
    if (_preparing) return;
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      if (!_prepared) {
        await _player.setUrl(SermonAudioService.urlFor(_part));
        _prepared = true;
      }
      await _player.play();
    } catch (e) {
      // A 404 on this host is an HTML error page, not an audio stream,
      // so the decoder fails rather than the request. Either way the
      // reader is told once and left with the transcript.
      if (mounted) setState(() => _error = _s('sermonAudioFailed', ''));
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  Future<void> _selectPart(int i) async {
    if (i == _index) return;
    await _player.stop();
    setState(() {
      _index = i;
      _prepared = false;
    });
    await _play();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Every size below goes through WbType, so the reader's Font Size
    // setting moves them. `scaledChrome` rather than `scaled`: a player
    // is frame furniture, not reading text.
    final t = WbType.of(context);
    if (widget.parts.isEmpty) return const SizedBox.shrink();

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(
          _error!,
          style: TextStyle(
              fontSize: t.scaledChrome(12), color: scheme.onSurfaceVariant),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // Square, like the rest of this app's chrome. #279 took the
      // rounded corners out on purpose and a ratchet keeps them out.
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            StreamBuilder<PlayerState>(
              stream: _player.playerStateStream,
              builder: (context, snap) {
                final state = sermonAudioControl(
                  playing: snap.data?.playing ?? false,
                  preparing: _preparing,
                  processing: snap.data?.processingState,
                );
                final playing = state.showPause;
                final waiting = state.waiting;
                return IconButton(
                  key: const ValueKey('sermonAudioToggle'),
                  onPressed: waiting
                      ? null
                      : (playing ? _player.pause : _play),
                  icon: waiting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded),
                  tooltip: playing
                      ? _s('sermonAudioPause', 'Pause')
                      : _s('sermonAudioPlay', 'Play'),
                );
              },
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _s('sermonAudioTitle', 'Recording'),
                    style: TextStyle(
                        fontSize: t.scaledChrome(12),
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface),
                  ),
                  // The size, until the element can tell us a duration.
                  // Both are honest; neither is guessed.
                  StreamBuilder<Duration?>(
                    stream: _player.durationStream,
                    builder: (context, snap) {
                      final d = snap.data;
                      final text = d != null
                          ? _clock(d)
                          : SermonAudioService.sizeLabel(_part.bytes);
                      return Text(
                        text,
                        style: TextStyle(
                            fontSize: t.scaledChrome(11),
                            color: scheme.onSurfaceVariant),
                      );
                    },
                  ),
                ],
              ),
            ),
            if (widget.parts.length > 1)
              for (var i = 0; i < widget.parts.length; i++)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: ChoiceChip(
                    label: Text(widget.parts[i].part.toUpperCase()),
                    selected: i == _index,
                    onSelected: (_) => _selectPart(i),
                  ),
                ),
          ]),
          // Seeking works: the host answers ranged requests, verified
          // with two real 206s including a mid-file one. Without that
          // this bar would be a lie, so it is only here because it was
          // measured.
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snap) {
              final total = _player.duration;
              if (total == null || total.inMilliseconds == 0) {
                return const SizedBox(height: 8);
              }
              final pos = snap.data ?? Duration.zero;
              final value = (pos.inMilliseconds / total.inMilliseconds)
                  .clamp(0.0, 1.0);
              return Row(children: [
                Text(_clock(pos),
                    style: TextStyle(
                        fontSize: t.scaledChrome(11),
                        color: scheme.onSurfaceVariant)),
                Expanded(
                  child: Slider(
                    value: value,
                    onChanged: (v) => _player.seek(total * v),
                  ),
                ),
                Text(_clock(total - pos),
                    style: TextStyle(
                        fontSize: t.scaledChrome(11),
                        color: scheme.onSurfaceVariant)),
              ]);
            },
          ),
          // Whose file this is, and where it is. Not a footnote: the
          // bandwidth is the church's, the recording is the church's,
          // and a reader who wants the source should not have to guess.
          Text(
            kIsWeb
                ? _s('sermonAudioSourceWeb', '')
                : _s('sermonAudioSource', ''),
            style: TextStyle(
                fontSize: t.scaledChrome(11), color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  static String _clock(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(h > 0 ? 2 : 1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}

/// Strings this widget owns, kept local for the same reason the wheel's
/// are: the unattended loop shares this checkout and edits
/// `ui_strings.dart`. Fold them in on a quiet merge.
const Map<String, Map<String, String>> sermonAudioStrings = {
  'sermonAudioTitle': {
    'zh-Hans': '录音', 'zh-Hant': '錄音', 'en': 'Recording',
  },
  'sermonAudioPlay': {
    'zh-Hans': '播放', 'zh-Hant': '播放', 'en': 'Play',
  },
  'sermonAudioPause': {
    'zh-Hans': '暂停', 'zh-Hant': '暫停', 'en': 'Pause',
  },
  'sermonAudioFailed': {
    'zh-Hans': '此讲道的录音暂时无法播放；讲稿仍可阅读。',
    'zh-Hant': '此講道的錄音暫時無法播放；講稿仍可閱讀。',
    'en': 'This recording could not be played just now. The transcript '
        'below is unaffected.',
  },
  'sermonAudioSource': {
    'zh-Hans': '录音由 Christian Disciples Church 提供并托管。',
    'zh-Hant': '錄音由 Christian Disciples Church 提供並託管。',
    'en': 'Recording provided and hosted by Christian Disciples Church.',
  },
  'sermonAudioSourceWeb': {
    'zh-Hans': '录音由 Christian Disciples Church 提供并托管；网页版只能在线收听。',
    'zh-Hant': '錄音由 Christian Disciples Church 提供並託管；網頁版只能線上收聽。',
    'en': 'Recording provided and hosted by Christian Disciples Church. '
        'On the web it streams only — it cannot be saved for offline use.',
  },
};
