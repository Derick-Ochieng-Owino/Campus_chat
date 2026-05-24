class StudentIdModel {
  final String uid;
  final String fullName;
  final String regNumber;
  final String course;
  final String school;
  final String validity;
  final String? profilePhotoUrl;
  final String? localPhotoPath;

  const StudentIdModel({
    required this.uid,
    required this.fullName,
    required this.regNumber,
    required this.course,
    required this.school,
    required this.validity,
    this.profilePhotoUrl,
    this.localPhotoPath,
  });

  factory StudentIdModel.fromMap(String uid, Map<String, dynamic> map) {
    return StudentIdModel(
      uid: uid,
      fullName: (map['full_name'] ?? '').toString(),
      regNumber: (map['reg_number'] ?? '').toString(),
      course: (map['course'] ?? 'BSc. Information Technology').toString(),
      school: (map['school'] ?? 'COPAS').toString(),
      validity: (map['validity'] ?? '2024-2028').toString(),
      profilePhotoUrl: map['profile_photo_url']?.toString(),
      localPhotoPath: map['local_photo_path']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'full_name': fullName,
      'reg_number': regNumber,
      'course': course,
      'school': school,
      'validity': validity,
      'profile_photo_url': profilePhotoUrl,
      'local_photo_path': localPhotoPath,
    };
  }

  StudentIdModel copyWith({
    String? uid,
    String? fullName,
    String? regNumber,
    String? course,
    String? school,
    String? validity,
    String? profilePhotoUrl,
    String? localPhotoPath,
  }) {
    return StudentIdModel(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      regNumber: regNumber ?? this.regNumber,
      course: course ?? this.course,
      school: school ?? this.school,
      validity: validity ?? this.validity,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      localPhotoPath: localPhotoPath ?? this.localPhotoPath,
    );
  }
}