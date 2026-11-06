import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart' show TtfParser;
import 'package:scinode/models/analytics.dart';
import 'package:scinode/services/analytics_pdf.dart';
import 'package:scinode/services/report_pdf.dart';
import 'package:scinode/strings.dart';
import 'package:scinode/strings_analytics.dart';
import 'package:shared_preferences/shared_preferences.dart';

// PDF «Scinode Аналитика» на настоящих файлах расчёта (5 ноября 2026).
OrgReport _r(String id) => OrgReport.fromJson(
    jsonDecode(File('test/fixtures/analytics/orgs/$id.json').readAsStringSync())
        as Map<String, dynamic>);

void main() {
  late ReportFonts fonts;
  late TtfParser regular;

  setUpAll(() {
    ByteData read(String f) =>
        ByteData.sublistView(File('assets/fonts/$f').readAsBytesSync());
    fonts = ReportFonts.fromBytes(
        read('NotoSans-Regular.ttf'), read('NotoSans-Bold.ttf'));
    regular = TtfParser(read('NotoSans-Regular.ttf'));
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('в шрифте есть все буквы текстов и названий организаций', () {
    final index = jsonDecode(
            File('test/fixtures/analytics/index.json').readAsStringSync())
        as Map<String, dynamic>;
    final texts = [
      for (final v in analyticsStrings.values) ...v,
      for (final o in AnalyticsIndex.fromJson(index).orgs) ...[
        o.name,
        ...o.alt,
        ...o.acronyms,
      ],
      for (final id in ['I47151758', 'I55383850', 'UZ']) ...[
        for (final a in _r(id).authors) a.name,
        for (final j in _r(id).journals) j.name,
        for (final p in _r(id).partners) p.name,
        for (final f in _r(id).funding!.top) f.name,
        for (final l in _r(id).languages) l.name,
      ],
    ];
    final missing = <String>{};
    for (final s in texts) {
      for (final r in s.runes) {
        if (r > 32 && !regular.charToGlyphIndexMap.containsKey(r)) {
          missing.add(String.fromCharCode(r));
        }
      }
    }
    expect(missing, isEmpty);
  });

  test('имя файла без запрещённых символов', () {
    expect(
        analyticsFileName(
            'National University of Uzbekistan', DateTime(2026, 11, 5)),
        'Scinode_National_University_of_Uzbekistan_2026-11-05.pdf');
    expect(analyticsFileName('a/b:c*d?', DateTime(2026, 1, 2)),
        'Scinode_a_b_c_d_2026-01-02.pdf');
  });

  for (final lang in ['ru', 'uz', 'en']) {
    test('PDF по вузу и сравнение собираются ($lang)', () async {
      await Strings.instance.setLang(lang);
      final nuu = _r('I47151758');
      final uz = _r('UZ');
      final org = await buildOrgPdf(nuu, country: uz, fonts: fonts, lang: lang);
      final country = await buildOrgPdf(uz, fonts: fonts, lang: lang);
      final cmp =
          await buildComparePdf(nuu, _r('I55383850'), fonts: fonts, lang: lang);
      for (final b in [org, country, cmp]) {
        expect(String.fromCharCodes(b.take(5)), '%PDF-');
        expect(b.length, greaterThan(20000));
      }
      // Для самопроверки глазами: SCINODE_PDF_OUT=папка flutter test …
      final out = Platform.environment['SCINODE_PDF_OUT'];
      if (out != null) {
        File('$out/org_$lang.pdf').writeAsBytesSync(org);
        File('$out/country_$lang.pdf').writeAsBytesSync(country);
        File('$out/compare_$lang.pdf').writeAsBytesSync(cmp);
      }
    });
  }
}
