import '../strings.dart';
import '../strings_science.dart';

class SciField {
  const SciField(this.id, this.name);
  final String id;
  final String name;
}

class SciSubfield {
  const SciSubfield(this.id, this.name, this.fieldId);
  final String id;
  final String name;
  final String fieldId;
}

/// Выбранное направление: область ('f17') или поддисциплина ('s1702').
class TagRef {
  const TagRef({required this.tag, required this.name});
  final String tag;
  final String name; // английское название

  bool get isField => tag.startsWith('f');
  String get rawId => tag.substring(1);
  String get label => isField ? localFieldName(name) : name;

  Map<String, dynamic> toJson() => {'t': tag, 'n': name};

  factory TagRef.fromJson(Map<String, dynamic> j) =>
      TagRef(tag: (j['t'] ?? '').toString(), name: (j['n'] ?? '').toString());
}

String localFieldName(String en) {
  final row = fieldNamesLocal[en];
  if (row == null) return en;
  switch (Strings.instance.lang) {
    case 'ru':
      return row[0];
    case 'uz':
      return row[1];
    default:
      return en;
  }
}

String countryName(String code) {
  for (final c in countryList) {
    if (c.$1 == code) {
      switch (Strings.instance.lang) {
        case 'ru':
          return c.$2;
        case 'uz':
          return c.$3;
        default:
          return c.$4;
      }
    }
  }
  return code;
}
