/// 2026-09-08 (SeekSparks): which translation the Exegesis panel draws
/// its interlinear against, and how that one is picked.
///
/// The panel used to answer only "what are this verse's original words",
/// one card per word with its number and a gloss. The owner asked for
/// what 微读圣经 and 精读圣经 do instead — 「我想好像微读圣经一样可以选
/// 译本 我提供这么多 然后这样看也容易些」 — a running line of a
/// translation the reader actually reads, with the numbers set into it:
///
///     地<0776>是<01961>空虚<08414>混沌<0922>，渊<08415>面<06440>黑暗<02822>；
///
/// That needs an EDITION, because the numbers are attached to a
/// particular rendering: `assets/tagged/<version>/<book>.json` holds one
/// run of that edition's own printed text per original word. So the
/// panel grows a picker, and this file is the part of the picker worth
/// testing — which rows it may show, and which row it opens on.
///
/// ## Which editions may be offered, and why the other two may not
///
/// [interlinearEditions] is an INTERSECTION, and both halves are load
/// bearing:
///
///   * `TaggedTextService.taggedVersions` — the editions that have the
///     alignment at all. Eight.
///   * `availableVersions` — the editions the app is willing to show a
///     reader anywhere. That is where `disabledVersions` is applied.
///
/// `assets/tagged/` holds NINE directories on disk and only six may
/// appear here. (2026-09-08: was "SEVEN … only five", before `bsb-yhwh`
/// and `asv-yhwh` were imported and before `bsb` was hidden.) The three
/// that drop out drop out for unrelated reasons, which is why the gate
/// is a set intersection and not a hand-written list that would have to
/// remember all three:
///
///   * **`nsn-plus`** (Eagle's View NASB) is not in `taggedVersions`,
///     is `.gitignore`d, and is not declared in `pubspec.yaml`. It is
///     on a developer's disk and in no build. Offering it would put a
///     row in the picker that opens an asset the shipped app does not
///     contain — and it is the NASB, whose permission is the one still
///     out with the publisher (see `disabledVersions`).
///   * **`cuvs-plus`** (和合本＋) IS tagged and IS bundled, but it is in
///     `disabledVersions` as of today: 「有雅+ 就不用和合本+了」. It is
///     the same base text as `cuvs-yhwh` with the divine name left
///     rendered away, so a picker offering both would be offering a
///     text and the same text. Reading it off `availableVersions` means
///     that decision is made in ONE place; a second list here would be
///     the way it silently comes back.
///   * **`bsb`** (2026-09-08, the same afternoon) for the same reason as
///     `cuvs-plus` and by the same mechanism: 「bsbs 不用，就 bsb yahweh
///     版本导入」. It IS tagged and IS bundled — `assets/tagged/bsb/` is
///     untouched and `test/bsb_tagged_test.dart` still reads it — and it
///     drops out here solely because `availableVersions` no longer
///     carries it. No code changed to make that happen, which is the
///     intersection earning its keep for the second time in one day.
///
/// That third exclusion moved the substitute an untagged English reader
/// lands on, and it took two passes to land somewhere defensible. `bsb`
/// held the slot; hiding it handed the slot to `csb`, purely because
/// catalog order put `csb` next — which meant an English reader who had
/// chosen nothing was quietly given a LICENSED text, copy-capped at 500
/// verses, in the same change that made the public-domain Yahweh
/// editions this app's defaults. Nobody decided that; catalog order did.
///
/// So the substitute now consults [localeDefaultVersion] first. That is
/// NOT the hand-ordered ranking rejected below: it is a decision the
/// catalog already makes, in one place, about which edition a reader of
/// a given language should get when they have expressed no preference —
/// which is exactly the question being asked here. English resolves to
/// `bsb-yhwh` and Chinese to `cuvs-yhwh`, and Chinese was already
/// getting that answer from catalog order, so only English moves.
///
/// When the locale default is not itself tagged the rule falls through
/// to catalog order unchanged, which is why that path is still here.
///
/// `lxxwh` stays, and that is deliberate rather than an oversight of a
/// Greek row in a translation picker. For the Old Testament the LXX is
/// a translation like any other and setting it beside the Hebrew
/// numbers is a real reading; for the New it is the original, and an
/// interlinear of the original against itself is a lemma-by-lemma line,
/// which is a thing readers of this app open the panel for. It is
/// tagged, it is bundled, and hiding it would be a narrowing this file
/// cannot justify.
///
/// ## Rejected: a hand-ordered "best first" list
///
/// The order is `availableVersions`' own catalog order. A ranking —
/// BSB first because it is the most completely aligned, say — would be
/// this file having an opinion about which translation is better, which
/// is not its business and not one the catalog anywhere else expresses.
///
/// Flutter-free apart from what it imports; nothing here touches an
/// asset, so every rule below is a pure function a test can call.
library;

import 'package:seeksparks/constants/bible_versions.dart';
import 'package:seeksparks/services/tagged_text_service.dart';

/// The edition codes the interlinear picker may list, in catalog order.
///
/// Computed rather than const because `availableVersions` is: an
/// imported edition can join it at runtime (it will never be tagged, so
/// it will never survive the filter, but the list still has to be read
/// fresh) and `disabledVersions` is read there rather than copied here.
List<String> get interlinearEditions => [
      for (final v in availableVersions)
        if (TaggedTextService.supports(v.value)) v.value,
    ];

/// Why the panel is showing the edition it is showing.
///
/// The panel prints a sentence for [substituted] and stays quiet for the
/// other two, which is the whole reason this is an enum and not a bool:
/// `strip_chronology_layout.dart`'s second rule — **nothing narrows in
/// silence** — is about exactly this case. A reader whose Bible has no
/// tagging is not shown an empty box and is not shown someone else's
/// translation unannounced; they are told which edition they are
/// looking at and why it is not theirs.
enum InterlinearSource {
  /// The reader picked this edition themselves.
  chosen,

  /// It is the edition they are reading, which happens to be tagged.
  current,

  /// Their edition has no tagging, so this is the nearest one that has.
  /// The only value the panel says anything about.
  substituted,

  /// Nothing is offerable at all. Unreachable while any tagged edition
  /// ships; represented because "the list is empty" and "the list has a
  /// first element" must not be the same code path.
  none,
}

/// The edition to draw, and how it was arrived at.
typedef InterlinearChoice = ({String? version, InterlinearSource source});

/// Pick the edition for a panel opened on [currentVersion].
///
/// [chosen] is the reader's own standing pick (`''` when they have never
/// touched the picker). It wins whenever it is still offerable, and is
/// ignored rather than honoured when it is not — an edition can leave
/// `availableVersions` between one launch and the next, and a stored
/// code is not a promise that it still exists.
///
/// After that the order is: the edition being read, then the nearest one
/// in the same language, then the first offered. "Nearest in the same
/// language" folds 简体 and 繁體 together on purpose. A 雅繁+ reader has
/// no traditional tagged edition to be given — `assets/tagged/` has no
/// traditional set and the app has no 简→繁 converter — and simplified
/// Chinese is a far better answer for them than English is. That is the
/// same fallback `ChineseLexiconService.isSimplifiedOnly` already makes
/// for the same reason.
InterlinearChoice resolveInterlinearEdition({
  String chosen = '',
  String? currentVersion,
}) {
  final offered = interlinearEditions;
  if (offered.isEmpty) return (version: null, source: InterlinearSource.none);

  if (offered.contains(chosen)) {
    return (version: chosen, source: InterlinearSource.chosen);
  }

  final current = currentVersion?.toLowerCase();
  if (current != null && offered.contains(current)) {
    return (version: current, source: InterlinearSource.current);
  }

  final wanted = current == null ? null : _scriptFamilyOf(current);
  if (wanted != null) {
    // The edition this reader's language opens on when nothing has been
    // chosen — the same question this substitute is answering. Only
    // used when it is itself tagged; otherwise catalog order decides,
    // as it always did.
    final byLocale = localeDefaultVersion(bibleVersionLanguage(current!));
    if (offered.contains(byLocale) && _scriptFamilyOf(byLocale) == wanted) {
      return (version: byLocale, source: InterlinearSource.substituted);
    }
    for (final code in offered) {
      if (_scriptFamilyOf(code) == wanted) {
        return (version: code, source: InterlinearSource.substituted);
      }
    }
  }
  return (version: offered.first, source: InterlinearSource.substituted);
}

/// `zh-Hans` and `zh-Hant` collapse to `zh`; everything else is its own
/// family. Null for a code the catalog does not know, which is what an
/// imported edition is — and a code with no language cannot steer a
/// fallback, so it falls through to "the first offered" rather than
/// being guessed at as Chinese the way [bibleVersionLanguage] guesses.
String? _scriptFamilyOf(String code) {
  for (final v in availableVersions) {
    if (v.value != code) continue;
    return v.language.startsWith('zh') ? 'zh' : v.language;
  }
  return null;
}
