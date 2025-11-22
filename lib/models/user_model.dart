class UserModel {
  final String uid;
  final String name;
  final String email;
  final String role;     // student | class_rep | assistant_rep | lecturer
  final String course;   // e.g., "CS"
  final int year;        // e.g., 2

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.course,
    required this.year,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> data) {
    return UserModel(
      uid: uid,
      name: data["name"] ?? "",
      email: data["email"] ?? "",
      role: data["role"] ?? "student",
      course: data["course"] ?? "",
      year: data["year"] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      "name": name,
      "email": email,
      "role": role,
      "course": course,
      "year": year,
    };
  }
}
