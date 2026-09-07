/// Which licence line belongs to which bundled edition.
///
/// The values are `ui_strings` keys, not sentences. Copying a verse out of
/// the app puts publisher text on someone else's page, which is exactly the
/// moment the licence has to travel with it — and for NASB and LEB that is
/// a condition of the permission we hold, not a courtesy. Reusing the keys
/// the About page already renders means the copied line is wording that has
/// been reviewed, in the reader's own locale, instead of a second set of
/// licence claims drafted at the clipboard.
///
/// Every code in `bibleVersions` must appear here; `attributionKeyFor`
/// returns null for anything unknown so a future edition fails by omitting
/// a line rather than by asserting a licence it does not have.
library;

import 'package:seeksparks/utils/imported_version.dart'
    show isImportedVersion, kImportedAttributionKey;

const versionAttributionKeys = <String, String>{
  'kjv': 'aboutLicensePublicDomain',
  'leb': 'aboutLicenseLeb',
  'nasb': 'aboutLicenseNasb',
  'bsb': 'aboutLicenseBsb',
  'csb': 'aboutLicenseCsb',
  // The three Eagle's View imports share one line: the texts themselves are
  // public domain, the electronic edition and its Strong's alignment are not.
  'kjvs': 'aboutLicenseEaglesView',
  'lxxwh': 'aboutLicenseEaglesView',
  'cuvs-plus': 'aboutLicenseEaglesView',
  'cuvs-yhwh': 'aboutLicenseCuvsYhwh',
  'cuvs-yhwh-tr': 'aboutLicenseCuvsYhwh',
  'biblexg-v2': 'aboutLicenseLjk',
  'biblexg-v2-tr': 'aboutLicenseLjk',
};

String? attributionKeyFor(String versionCode) {
  // bwh47. An imported text has no key of its own and this app cannot
  // verify what it is, so it carries a DISCLAIMER rather than a licence
  // — which is this file's own rule, stated at the top: fail by omitting
  // a line rather than by asserting one we do not have.
  if (isImportedVersion(versionCode)) return kImportedAttributionKey;
  return versionAttributionKeys[versionCode];
}

/// Editions whose text may be copied out in any quantity: the
/// translation itself is public domain, so no permission is being spent.
///
/// The three Eagle's View rows are here because what is licensed about
/// them is the electronic edition and its Strong's alignment, neither of
/// which travels on the clipboard — copying KJV+S copies the 1769 KJV.
const unrestrictedCopyVersions = <String>{
  'kjv',
  'bsb',
  'kjvs',
  'lxxwh',
  'cuvs-plus',
};

/// How many verses of a *licensed* edition one copy may take.
///
/// This is not a performance guard. The Lockman Foundation's published
/// quotation provision for the NASB — the permission the About page
/// claims we are using — allows up to 500 verses without written
/// consent, and the other permissions we hold are narrower still
/// ("non-commercial study only"). A Copy Center with no ceiling is a bulk
/// text exporter with extra steps, and would let a reader walk past that
/// line without ever being told there was one.
///
/// 500 is the ceiling, so it is applied to every restricted edition
/// rather than only to NASB: the number that governs is the tightest one
/// among the versions actually selected, and none of them is looser.
const kLicensedCopyVerseLimit = 500;

bool copyIsRestricted(Iterable<String> versionCodes) =>
    versionCodes.any((c) => !unrestrictedCopyVersions.contains(c));
