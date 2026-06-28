import 'dart:convert';

class Unit {
  final String id;
  final String name;
  final int year;
  final int semester;

  Unit({required this.id, required this.name, required this.year, required this.semester});

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'year': year,
    'semester': semester,
  };

  static Unit fromJsonMap(Map<String, dynamic> m) {
    return Unit(
      id: m['id'] as String,
      name: m['name'] as String,
      year: m['year'] as int,
      semester: m['semester'] as int,
    );
  }

  static String encodeList(List<Unit> units) => jsonEncode(units.map((u) => u.toJson()).toList());

  static List<Unit> decodeList(String encoded) {
    final list = jsonDecode(encoded) as List<dynamic>;
    return list.map((e) => Unit.fromJsonMap(e as Map<String, dynamic>)).toList();
  }
}