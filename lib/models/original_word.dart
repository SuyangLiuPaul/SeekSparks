/// One word of the original-language Bible text (Hebrew OT or Greek NT).
///
/// `text` is the surface form as it appears in the source; `strongs` is
/// the Strong's number ("G####"/"H####") that links to a [StrongsEntry].
/// `translit` is optional — included when the source provides it inline
/// so we don't have to look it up separately.
///
/// `ketivQere` is null, or one of four roles the Masoretes distinguish —
/// `'k'`/`'q'` for a written form and the reading directed in its place,
/// `'kx'` for a word written but marked not to be read at all, `'qx'` for
/// one read though the text writes nothing. See `lib/utils/ketiv_qere.dart`.
class OriginalWord {
  final String text;
  final String strongs;
  final String? translit;
  final String? morph;
  final String? ketivQere;

  const OriginalWord({
    required this.text,
    required this.strongs,
    this.translit,
    this.morph,
    this.ketivQere,
  });

  /// A written form — either kind. True for the word the eye should
  /// pass over, which is why both `k` and `kx` answer to it.
  bool get isKetiv => ketivQere == 'k' || ketivQere == 'kx';
  bool get isQere => ketivQere == 'q' || ketivQere == 'qx';

  factory OriginalWord.fromJson(Map<String, dynamic> json) {
    final kq = json['kq'] as String?;
    return OriginalWord(
      text: (json['w'] ?? '') as String,
      strongs: (json['s'] ?? '') as String,
      translit: json['t'] as String?,
      morph: json['m'] as String?,
      ketivQere: const {'k', 'q', 'kx', 'qx'}.contains(kq) ? kq : null,
    );
  }
}
