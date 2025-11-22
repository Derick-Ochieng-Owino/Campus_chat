class GroupModel {
  final String id;
  final String name;                // "Group 5"
  final String course;              // "CS"
  final int year;                   // 2
  final List<String> members;       // UIDs of students

  GroupModel({
    required this.id,
    required this.name,
    required this.course,
    required this.year,
    required this.members,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> data) {
    return GroupModel(
      id: id,
      name: data["name"] ?? "",
      course: data["course"] ?? "",
      year: data["year"] ?? 1,
      members: List<String>.from(data["members"] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "course": course,
      "year": year,
      "members": members,
    };
  }
}
