import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scinode/models/grant.dart';

/// Реальные ответы API, сохранённые 05.11.2026 (test/fixtures/grants).
Map<String, dynamic> _fx(String name) =>
    jsonDecode(File('test/fixtures/grants/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  // Момент «сейчас» для тестов: 5 ноября 2026, 04:00 UTC.
  final now = DateTime.utc(2026, 11, 5, 4);

  group('EU Funding & Tenders (SEDIA)', () {
    final calls = parseEuSearch(_fx('eu_search.json'), now);

    GrantCall byRef(String ref) => calls.firstWhere((c) => c.id == ref);

    test('разобраны все 6 конкурсов (темы, каскадные, EuropeAid)', () {
      expect(calls.length, 6);
      expect(calls.map((c) => c.kind).toSet(), {'1', '2', '8'});
      expect(calls.every((c) => c.source == GrantSource.eu), isTrue);
      expect(calls.every((c) => c.status == CallStatus.open), isTrue);
    });

    test('многоэтапный конкурс: берётся ближайший будущий дедлайн', () {
      final c = byRef('44774210ERASMUSECHECharter1645574400000');
      expect(c.number, 'ERASMUS-EDU-2022-ECHE-CERT-FP');
      expect(c.title, 'Erasmus Charter for Higher Education');
      expect(c.deadline, DateTime.utc(2027, 1, 26, 17));
      expect(c.deadlines.length, 1); // прошедшие этапы отброшены
      expect(c.agency, 'ERASMUS ECHE Charter');
      expect(c.openDate, DateTime.utc(2022, 2, 23));
    });

    test('ссылка .json заменяется на страницу портала', () {
      final c = byRef('44774210ERASMUSECHECharter1645574400000');
      expect(
        c.url,
        'https://ec.europa.eu/info/funding-tenders/opportunities/portal/'
        'screen/opportunities/topic-details/ERASMUS-EDU-2022-ECHE-CERT-FP',
      );
    });

    test('каскадное финансирование: бюджет и название программы', () {
      final c = byRef('11145COMPETITIVE_CALLen');
      expect(c.title, 'Gnomon Internships Offer');
      expect(
          c.agency, 'Specialised education programmes in key capacity areas');
      expect(c.budget, 120000);
      expect(c.currency, 'EUR');
      expect(c.deadline, DateTime.utc(2027, 1, 3, 4, 59));
      expect(c.deadlines.length, 4);
      expect(c.url, contains('/competitive-calls-cs/'));
    });

    test('EuropeAid: дедлайн сегодня вечером — «последний день»', () {
      final c = byRef('187686PROSPECTSEN');
      expect(c.number, 'EuropeAid/187686/ID/ACT/MK');
      expect(c.budget, 1300000);
      expect(c.deadline, DateTime.utc(2026, 11, 5, 22, 59));
      expect(daysLeft(c.deadline!, now), 0);
    });

    test('конкурс с прошедшим дедлайном отбрасывается', () {
      final later = DateTime.utc(2026, 11, 5, 23, 30);
      final ids = parseEuSearch(_fx('eu_search.json'), later).map((c) => c.id);
      expect(ids, isNot(contains('187686PROSPECTSEN')));
    });

    test('скоро открывающиеся конкурсы', () {
      final f = parseEuSearch(_fx('eu_forthcoming.json'), now);
      expect(f.length, 2);
      expect(f.every((c) => c.status == CallStatus.forthcoming), isTrue);
      final c = f.firstWhere((c) => c.number == 'HORIZON-CL5-2027-07-D3-32');
      expect(c.openDate, DateTime.utc(2027, 8, 4));
      expect(c.deadline, DateTime.utc(2027, 12, 1));
    });

    test('закупки (type 0) и закрытые конкурсы пропускаются', () {
      Map<String, dynamic> rec(String type, String status) => {
            'reference': 'x$type$status',
            'metadata': {
              'type': [type],
              'status': [status],
              'identifier': ['X'],
              'title': ['T'],
              'deadlineDate': ['2027-01-01T00:00:00.000+0000'],
            },
          };
      final r = parseEuSearch({
        'results': [
          rec('0', euStatusOpen),
          rec('1', '31094503'),
          rec('1', euStatusOpen),
        ],
      }, now);
      expect(r.map((c) => c.id), ['x131094502']);
    });

    test('пустой или странный ответ не ломает разбор', () {
      expect(parseEuSearch({}, now), isEmpty);
      expect(parseEuSearch({'results': 'oops'}, now), isEmpty);
    });
  });

  group('Grants.gov', () {
    test('posted: прошедший вчера дедлайн отброшен', () {
      final calls = parseGrantsGovSearch(_fx('grantsgov_posted.json'), now);
      expect(calls.map((c) => c.number), isNot(contains('P27AS00032')));
      expect(calls.length, 3);
    });

    test('поля конкурса', () {
      final calls = parseGrantsGovSearch(_fx('grantsgov_posted.json'), now);
      final c = calls.firstWhere((c) => c.number == 'G27AS00164');
      expect(c.id, '364012');
      expect(c.title, startsWith('WATER RESOURCES RESEARCH ACT PROGRAM'));
      expect(c.agency, 'Geological Survey');
      expect(c.status, CallStatus.open);
      expect(c.openDate, DateTime(2026, 9, 30));
      expect(c.deadline, DateTime(2026, 11, 12));
      expect(c.url, 'https://www.grants.gov/search-results-detail/364012');
      expect(daysLeft(c.deadline!, now), 7);
      expect(urgencyOf(c.deadline, now), Urgency.urgent);
    });

    test('forecasted: без дедлайна, статус «скоро»', () {
      final calls = parseGrantsGovSearch(_fx('grantsgov_forecasted.json'), now);
      expect(calls.length, 2);
      final c = calls.firstWhere((c) => c.number == 'TI-27-006');
      expect(c.status, CallStatus.forthcoming);
      expect(c.deadline, isNull);
      expect(c.openDate, DateTime(2026, 10, 30));
      expect(urgencyOf(c.deadline, now), Urgency.none);
    });

    test('подробности конкурса (synopsis)', () {
      final d = parseGrantsGovDetails(_fx('grantsgov_fetch.json'));
      expect(d.awardCeiling, 120000);
      expect(d.awardFloor, isNull); // 0 не показываем
      expect(d.totalFunding, 462500);
      expect(d.awardsCount, 4);
      expect(d.costSharing, isTrue);
      expect(d.instruments, ['Grant']);
      expect(d.applicantTypes.single, startsWith('Others'));
      expect(d.eligibility, startsWith('Only Water Resources Research'));
      expect(d.description, startsWith('This Program Announcement'));
      expect(d.description, isNot(contains('<p>')));
      expect(d.agencyName, 'Geological Survey');
    });

    test('подробности прогноза (forecast)', () {
      final d = parseGrantsGovDetails(_fx('grantsgov_fetch_forecast.json'));
      expect(d.totalFunding, 20000000);
      expect(d.awardsCount, 40);
      expect(d.instruments, ['Cooperative Agreement']);
      expect(d.description, startsWith('The purpose of this program'));
      expect(d.eligibility, startsWith('Eligibility for this program'));
    });

    test('пустой ответ', () {
      expect(parseGrantsGovSearch({}, now), isEmpty);
      final d = parseGrantsGovDetails({});
      expect(d.description, '');
      expect(d.awardCeiling, isNull);
    });
  });

  group('Сортировка конкурсов', () {
    test('по ближайшему дедлайну, без дедлайна — в конце', () {
      final all = [
        ...parseGrantsGovSearch(_fx('grantsgov_forecasted.json'), now),
        ...parseEuSearch(_fx('eu_search.json'), now),
        ...parseGrantsGovSearch(_fx('grantsgov_posted.json'), now),
      ];
      sortCalls(all);
      expect(all.first.number, 'EuropeAid/187686/ID/ACT/MK');
      expect(all[1].number, 'G27AS00164');
      expect(all.last.deadline, isNull);
      final dated = all.where((c) => c.deadline != null).toList();
      for (var i = 1; i < dated.length; i++) {
        expect(dated[i].deadline!.isBefore(dated[i - 1].deadline!), isFalse);
      }
    });
  });

  group('NIH RePORTER', () {
    final list = parseNih(_fx('nih_search.json'));

    test('поля проекта', () {
      expect(list.length, 3);
      final p = list.first;
      expect(p.source, GrantSource.nih);
      expect(p.number, '1R21EB036894-01A1');
      expect(p.title, startsWith('Exploring Entangled Photons'));
      expect(p.organization, 'SCRIPPS RESEARCH INSTITUTE, THE');
      expect(p.place, 'LA JOLLA, CA, UNITED STATES');
      expect(p.investigators, ['Ashok A Deniz']);
      expect(p.amount, 276000);
      expect(p.currency, 'USD');
      expect(p.start, DateTime(2026, 8, 1));
      expect(p.end, DateTime(2028, 7, 31));
      expect(p.url, 'https://reporter.nih.gov/project-details/11320635');
      expect(p.program,
          'National Institute of Biomedical Imaging and Bioengineering');
      expect(p.abstractText, isNotEmpty);
    });

    test('двойные пробелы в именах убираются', () {
      expect(list[1].investigators, ['Filiz Yesilkoy']);
    });
  });

  group('NSF', () {
    final list = parseNsf(_fx('nsf_awards.json'));

    test('поля награды', () {
      expect(list.length, 3);
      final p = list.first;
      expect(p.source, GrantSource.nsf);
      expect(p.number, '2609791');
      expect(p.title, startsWith('High-Mobility Germanium-on-AlAs'));
      expect(p.organization,
          'Virginia Polytechnic Institute and State University');
      expect(p.place, 'BLACKSBURG, VA');
      expect(p.investigators.first, 'Mantu K Hudait');
      expect(p.amount, 451000);
      expect(p.start, DateTime(2026, 10, 15));
      expect(p.end, DateTime(2029, 9, 30));
      expect(p.url, 'https://www.nsf.gov/awardsearch/showAward?AWD_ID=2609791');
      expect(p.program, startsWith('EPMQD'));
    });

    test('ключевые слова соединяются через AND', () {
      expect(nsfKeyword('quantum  sensing'), 'quantum AND sensing');
      expect(nsfKeyword('"soil carbon"'), 'soil AND carbon');
      expect(nsfKeyword('  '), '');
    });

    test('сортировка проектов: новые сверху', () {
      final all = [...list, ...parseNih(_fx('nih_search.json'))];
      sortProjects(all);
      expect(all.first.start, DateTime(2026, 10, 15));
      expect(all.last.start, DateTime(2025, 8, 1));
    });
  });

  group('Даты', () {
    test('parseUsDate', () {
      expect(parseUsDate('11/12/2026'), DateTime(2026, 11, 12));
      expect(parseUsDate('1/2/2027'), DateTime(2027, 1, 2));
      expect(parseUsDate(''), isNull);
      expect(parseUsDate('2026-11-12'), isNull);
      expect(parseUsDate('13/01/2026'), isNull);
      expect(parseUsDate(null), isNull);
    });

    test('parseIsoDate понимает +0000 без двоеточия', () {
      expect(parseIsoDate('2027-01-26T17:00:00.000+0000'),
          DateTime.utc(2027, 1, 26, 17));
      expect(parseIsoDate('2026-05-24T00:00:00Z'), DateTime.utc(2026, 5, 24));
      expect(parseIsoDate('2026-09-01T00:00:00'), DateTime(2026, 9, 1));
      expect(parseIsoDate('garbage'), isNull);
    });

    test('daysLeft и срочность', () {
      final n = DateTime(2026, 11, 5, 15);
      expect(daysLeft(DateTime(2026, 11, 5), n), 0);
      expect(daysLeft(DateTime(2026, 11, 6), n), 1);
      expect(daysLeft(DateTime(2026, 11, 4), n), -1);
      expect(daysLeft(DateTime(2027, 11, 5), n), 365);
      expect(urgencyOf(DateTime(2026, 11, 12), n), Urgency.urgent);
      expect(urgencyOf(DateTime(2026, 11, 13), n), Urgency.soon);
      expect(urgencyOf(DateTime(2026, 12, 5), n), Urgency.soon);
      expect(urgencyOf(DateTime(2026, 12, 6), n), Urgency.normal);
    });

    test('formatDate', () {
      final d = DateTime(2026, 3, 7);
      expect(formatDate(d, 'ru'), '07.03.2026');
      expect(formatDate(d, 'uz'), '07.03.2026');
      expect(formatDate(d, 'en'), '2026-03-07');
    });
  });

  group('Форматирование', () {
    test('pluralForm для русского', () {
      expect(pluralForm(1, 'ru'), 'one');
      expect(pluralForm(21, 'ru'), 'one');
      expect(pluralForm(2, 'ru'), 'few');
      expect(pluralForm(24, 'ru'), 'few');
      expect(pluralForm(5, 'ru'), 'many');
      expect(pluralForm(11, 'ru'), 'many');
      expect(pluralForm(12, 'ru'), 'many');
      expect(pluralForm(111, 'ru'), 'many');
    });

    test('pluralForm для английского и узбекского', () {
      expect(pluralForm(1, 'en'), 'one');
      expect(pluralForm(2, 'en'), 'many');
      expect(pluralForm(1, 'uz'), 'many');
    });

    test('formatMoney', () {
      expect(formatMoney(1234567, 'USD', 'en'), r'$1,234,567');
      expect(formatMoney(1234567, 'USD', 'ru'), '1 234 567 \$');
      expect(formatMoney(120000, 'EUR', 'en'), '€120,000');
      expect(formatMoney(999, 'EUR', 'uz'), '999 €');
      expect(formatMoney(100, '', 'en'), '100');
      expect(formatMoney(1000.6, 'USD', 'en'), r'$1,001');
    });

    test('stripHtml', () {
      expect(
        stripHtml('<p>A &amp; B</p><ul><li>one</li><li>two&nbsp;x</li></ul>'),
        'A & B\n• one\n• two x',
      );
      expect(stripHtml('It&#39;s <b>bold</b>'), "It's bold");
      expect(stripHtml(''), '');
    });

    test('squeeze', () {
      expect(squeeze('  Filiz   Yesilkoy '), 'Filiz Yesilkoy');
    });

    test('euPortalUrl оставляет обычные ссылки', () {
      const u = 'https://webgate.ec.europa.eu/prospect/x?callId=1';
      expect(euPortalUrl(u, 'X'), u);
      expect(euPortalUrl('', 'A/B'), endsWith('topic-details/A%2FB'));
    });
  });
}
