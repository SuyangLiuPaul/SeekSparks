import 'package:flutter_test/flutter_test.dart';
import 'package:seeksparks/models/app_style_preset.dart';
import 'package:seeksparks/utils/font_catalog.dart';

/// v1.6.62 removed the `google_fonts` package, which deleted fourteen
/// entries from the font catalogue. A key that is no longer in the
/// catalogue fails SILENTLY: the dropdown finds no matching item and
/// CanvasKit resolves nothing, so the app just renders its default.
/// Nothing throws and no test that only pumps a widget notices. These
/// are the checks that do.
void main() {
  group('migrateLegacyFontKey', () {
    test('a surviving key is returned untouched', () {
      for (final f in availableFontOptions()) {
        expect(migrateLegacyFontKey(f.key), f.key,
            reason: '${f.key} is in the catalogue and must not be migrated');
      }
    });

    test('every removed Google font resolves to the system face', () {
      // Not Roboto: these were chosen for comfortable prose, and the
      // reader's own OS face is the closer substitute.
      const removed = [
        'EB Garamond',
        'Lora',
        'Merriweather',
        'Crimson Pro',
        'Playfair Display',
        'Open Sans',
        'Inter',
        'Lato',
        'Nunito',
        'Montserrat',
        'Noto Serif SC',
        'Noto Sans SC',
        'ZCOOL XiaoWei',
        'Ma Shan Zheng',
      ];
      for (final k in removed) {
        expect(migrateLegacyFontKey(k), 'system', reason: k);
      }
    });

    test('a legacy CSS key routed through a since-removed font still '
        'lands in the catalogue', () {
      // The regression this guards: `_migrations` was written when
      // 'Georgia' → 'Lora' was a real destination. Lora is gone, so a
      // single-pass migration would hand back a key the picker does
      // not have — the exact silent failure described above.
      const legacyCss = [
        'Times New Roman',
        'Garamond',
        'Georgia',
        'Palatino',
        'Arial',
        'Helvetica',
        'Verdana',
        'system-ui',
        'Source Han Sans CN',
        'Heiti SC',
        'KaiTi',
        'Microsoft YaHei',
      ];
      for (final k in legacyCss) {
        expect(isValidFontKey(migrateLegacyFontKey(k)), isTrue, reason: k);
      }
    });

    test('an unrecognised key falls back to bundled Roboto', () {
      // Roboto, not system: if we cannot reason about where the value
      // came from, prefer the face that is physically present.
      expect(migrateLegacyFontKey('Comic Sans MS'), 'Roboto');
      expect(migrateLegacyFontKey(''), 'Roboto');
    });

    test('migration is idempotent', () {
      for (final k in ['Georgia', 'Inter', 'Roboto', 'nonsense', '']) {
        final once = migrateLegacyFontKey(k);
        expect(migrateLegacyFontKey(once), once, reason: k);
      }
    });
  });

  test('every style preset names a font the catalogue still has', () {
    // `modern`, `reverent`, `reader`, `paper`, `liquidGlass` and
    // `carbon` all pointed at Google Fonts before v1.6.62. Picking one
    // of those presets would have silently rendered the engine default
    // while the preset claimed a serif.
    for (final entry in presetDefinitions.entries) {
      expect(isValidFontKey(entry.value.fontFamily), isTrue,
          reason: '${entry.key} uses "${entry.value.fontFamily}", '
              'which is not in availableFontOptions()');
    }
  });
}
