import 'taxonomy.dart';

const profileRoles = [
  'student',
  'phd',
  'postdoc',
  'researcher',
  'professor',
  'industry',
];

/// Профиль учёного в Scinode.
class UserProfile {
  UserProfile({
    this.uid = '',
    this.name = '',
    this.role = 'researcher',
    this.org = '',
    this.country = '',
    this.bio = '',
    this.orcid = '',
    this.oaId = '',
    this.oaName = '',
    List<TagRef>? tags,
    this.published = false,
    this.updated,
  }) : tags = tags ?? <TagRef>[];

  String uid;
  String name;
  String role;
  String org;
  String country;
  String bio;
  String orcid;
  String oaId;
  String oaName;
  List<TagRef> tags;
  bool published;
  DateTime? updated;

  UserProfile copy() => UserProfile(
        uid: uid,
        name: name,
        role: role,
        org: org,
        country: country,
        bio: bio,
        orcid: orcid,
        oaId: oaId,
        oaName: oaName,
        tags: List<TagRef>.of(tags),
        published: published,
        updated: updated,
      );

  int get percent {
    var n = 0;
    if (name.trim().isNotEmpty) n++;
    if (org.trim().isNotEmpty) n++;
    if (country.isNotEmpty) n++;
    if (bio.trim().isNotEmpty) n++;
    if (tags.isNotEmpty) n++;
    if (oaId.isNotEmpty || orcid.trim().isNotEmpty) n++;
    return (n * 100 / 6).round();
  }

  Map<String, dynamic> toLocal() => {
        'name': name,
        'role': role,
        'org': org,
        'country': country,
        'bio': bio,
        'orcid': orcid,
        'oaId': oaId,
        'oaName': oaName,
        'tags': tags.map((e) => e.toJson()).toList(),
        'published': published,
      };

  factory UserProfile.fromLocal(Map<String, dynamic> j) => UserProfile(
        name: (j['name'] ?? '').toString(),
        role: (j['role'] ?? 'researcher').toString(),
        org: (j['org'] ?? '').toString(),
        country: (j['country'] ?? '').toString(),
        bio: (j['bio'] ?? '').toString(),
        orcid: (j['orcid'] ?? '').toString(),
        oaId: (j['oaId'] ?? '').toString(),
        oaName: (j['oaName'] ?? '').toString(),
        tags: [
          for (final e in (j['tags'] as List? ?? const []))
            TagRef.fromJson(Map<String, dynamic>.from(e as Map)),
        ],
        published: j['published'] == true,
      );

  /// Данные для публикации (без поля времени).
  Map<String, dynamic> toCloud() => {
        'n': name.trim(),
        'r': role,
        'o': org.trim(),
        'c': country,
        'b': bio.trim(),
        'orc': orcid.trim(),
        'oa': oaId,
        'oan': oaName,
        'tg': tags.map((e) => e.tag).toList(),
        'tn': tags.map((e) => e.name).toList(),
      };

  factory UserProfile.fromCloud(
    String uid,
    Map<String, dynamic> m,
    DateTime? updated,
  ) {
    final tg = (m['tg'] as List? ?? const []).map((e) => e.toString()).toList();
    final tn = (m['tn'] as List? ?? const []).map((e) => e.toString()).toList();
    return UserProfile(
      uid: uid,
      name: (m['n'] ?? '').toString(),
      role: (m['r'] ?? 'researcher').toString(),
      org: (m['o'] ?? '').toString(),
      country: (m['c'] ?? '').toString(),
      bio: (m['b'] ?? '').toString(),
      orcid: (m['orc'] ?? '').toString(),
      oaId: (m['oa'] ?? '').toString(),
      oaName: (m['oan'] ?? '').toString(),
      tags: [
        for (var i = 0; i < tg.length; i++)
          TagRef(tag: tg[i], name: i < tn.length ? tn[i] : ''),
      ],
      published: true,
      updated: updated,
    );
  }
}
