class UnitModel {
  final String id;
  final String name;      // Calculus I
  final String code;      // MAT 210
  final String course;    // CS
  final int year;         // 2
  final int semester;     // 1 or 2

  UnitModel({
    required this.id,
    required this.name,
    required this.code,
    required this.course,
    required this.year,
    required this.semester,
  });

  factory UnitModel.fromMap(String id, Map<String, dynamic> data) {
    return UnitModel(
      id: id,
      name: data["name"] ?? "",
      code: data["code"] ?? "",
      course: data["course"] ?? "",
      year: data["year"] ?? 1,
      semester: data["semester"] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "code": code,
      "course": course,
      "year": year,
      "semester": semester,
    };
  }
}
