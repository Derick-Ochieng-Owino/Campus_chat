class Permissions {
  static bool isClassRep(String role) =>
      role == "class_rep" || role == "assistant_rep";

  static bool isStudent(String role) => role == "student";
}
