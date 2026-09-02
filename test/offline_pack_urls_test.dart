/// EVERY URL THE OFFLINE PACK PRE-FETCHES MUST BE A FILE THAT SHIPS.
///
/// Until 2026-09-02 six of them were not. `assets/cuv.json`,
/// `cuv-tr`, `cnv`, `cnv-tr`, `biblexg` and `biblexg-tr` were removed
/// from the catalog and from `pubspec.yaml` when `cuvs-yhwh` and
/// `biblexg-v2` superseded them, and stayed in the pre-fetch list.
///
/// ON WEB THAT IS NOT A 404. `netlify.toml` redirects `/*` to
/// `/index.html` with status 200, so `fetch('assets/assets/cuv.json')`
/// returns the app's own HTML with a 200 and the pack stores it, under
/// a Bible's name, and reports success. A reader who tapped "download
/// for offline use" got six copies of index.html and no warning at all
/// — no exception, no log, nothing on screen. This is the shape of
/// defect a test has to catch, because nothing else can: it is invisible
/// from inside the app, and the SPA redirect that hides it is correct
/// and must stay.
///
/// So the invariant is checked from outside, in two directions: the
/// file is on disk, and it is declared in `pubspec.yaml` so it reaches
/// the build at all. A file can be present in the repo and absent from
/// the bundle, which fails exactly the same way.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// URLs the service builds by interpolation — one per book, per map,
/// per sermon — rather than listing. Their existence is the business of
/// the assets those loops read, and they are checked there.
bool _isTemplate(String url) => url.contains(r'$');

void main() {
  late final String src;
  late final String pubspec;
  late final List<String> urls;

  setUpAll(() {
    src = File('lib/services/offline_pack_service.dart').readAsStringSync();
    pubspec = File('pubspec.yaml').readAsStringSync();
    urls = RegExp(r"'(assets/[^']+)'")
        .allMatches(src)
        .map((m) => m.group(1)!)
        .where((u) => !_isTemplate(u))
        .toSet()
        .toList()
      ..sort();
  });

  test('the list is not empty, and every entry exists on disk', () {
    expect(urls, isNotEmpty);
    final missing = [for (final u in urls) if (!File(u).existsSync()) u];
    expect(missing, isEmpty,
        reason: 'the offline pack would fetch these and, on web, store '
            'index.html under their names');
  });

  test('every entry is declared in pubspec, so it is in the bundle', () {
    final undeclared = [
      for (final u in urls)
        if (!pubspec.contains(u) &&
            !pubspec.contains('${_dir(u)}/'))
          u
    ];
    expect(undeclared, isEmpty,
        reason: 'present in the repo, absent from the build — which fails '
            'exactly the way a deleted file does');
  });

  test('the six that were wrong are gone, and the ones that replaced them '
      'are here', () {
    for (final dead in const [
      'assets/cuv.json',
      'assets/cuv-tr.json',
      'assets/cnv.json',
      'assets/cnv-tr.json',
      'assets/biblexg.json',
      'assets/biblexg-tr.json',
      'assets/niv.json',
    ]) {
      expect(urls, isNot(contains(dead)));
      expect(File(dead).existsSync(), isFalse,
          reason: '$dead is back on disk — then the catalog decided '
              'something and this test should be told about it');
    }
    for (final live in const [
      'assets/cuvs-yhwh.json',
      'assets/cuvs-yhwh-tr.json',
      'assets/biblexg-v2.json',
      'assets/biblexg-v2-tr.json',
    ]) {
      expect(urls, contains(live));
    }
  });

  test('a hidden edition is not pre-fetched, and a visible one is', () {
    // The NASB still ships and is still hidden from every surface a
    // reader picks from, so spending 7.2 MB of someone's bandwidth on
    // it would be spending it on a Bible the app will not open. The LEB
    // was hidden alongside it for a few hours the same day and is back.
    expect(urls, isNot(contains('assets/nasb.json')));
    expect(File('assets/nasb.json').existsSync(), isTrue,
        reason: 'hiding was never a removal');
    expect(urls, contains('assets/leb.json'),
        reason: 'the LEB is on offer again and must be downloadable '
            'offline like every other edition a reader can choose');
  });
}

String _dir(String path) => path.substring(0, path.lastIndexOf('/'));
