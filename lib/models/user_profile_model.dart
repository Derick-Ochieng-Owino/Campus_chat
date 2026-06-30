import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  // final String fullName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String regNumber;
  final String phoneNumber;
  final DateTime birthDate;
  final String? profilePhotoUrl;
  final bool profileCompleted;
  final String university;
  final String campus;
  final String college;
  final String school;
  final String department;
  final String course;
  final String year;
  final String semester;
  final List<dynamic> registeredUnits;
  final String validityPeriod;

  UserProfile({
    required this.uid,
    //required this.fullName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.regNumber,
    required this.phoneNumber,
    required this.birthDate,
    this.profilePhotoUrl,
    required this.profileCompleted,
    required this.university,
    required this.campus,
    required this.college,
    required this.school,
    required this.department,
    required this.course,
    required this.year,
    required this.semester,
    required this.registeredUnits,
    required this.validityPeriod,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map, String docId) {
    return UserProfile(
      uid: docId,
      //fullName: map['full_name'] ?? 'STUDENT',
      firstName: map['first_name'] ?? 'FIRST NAME',
      middleName: map['middle_name'] ?? 'MIDDLE NAME',
      lastName: map['last_name'] ?? 'LAST NAME',
      regNumber: map['reg_number'] ?? 'REG NUMBER',
      phoneNumber: map['phone_number'] ?? map['phone'] ?? '',
      birthDate: map['birth_date'] != null ? DateTime.parse(map['birth_date']) : DateTime.now(),
      profilePhotoUrl: map['profile_photo_url'],
      profileCompleted: map['profile_completed'] ?? false,
      university: map['university'] ?? 'JOMO KENYATTA UNIVERSITY OF AGRICULTURE & TECHNOLOGY',
      campus: map['campus'] ?? 'Main Campus',
      college: map['college'] ?? 'COPAS',
      school: map['school'] ?? 'School of Computing and Information Technology',
      department: map['department'] ?? 'Computing',
      course: map['course'] ?? 'BSc. INFORMATION TECHNOLOGY',
      year: map['year']?.toString() ?? '2',
      semester: map['semester']?.toString() ?? '2',
      registeredUnits: map['registered_units'] ?? [],
      validityPeriod: map['validity_period'] ?? '2024-2028',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      //'full_name': fullName,
      'reg_number': regNumber,
      'phone_number': phoneNumber,
      'birth_date': birthDate.toIso8601String(),
      'profile_photo_url': profilePhotoUrl,
      'profile_completed': profileCompleted,
      'university': university,
      'campus': campus,
      'college': college,
      'school': school,
      'department': department,
      'course': course,
      'year': year,
      'semester': semester,
      'registered_units': registeredUnits,
      'validity_period': validityPeriod,
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}