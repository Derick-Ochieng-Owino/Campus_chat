import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final users = FirebaseFirestore.instance.collection("users");
  final units = FirebaseFirestore.instance.collection("units");
  final files = FirebaseFirestore.instance.collection("files");
  final groups = FirebaseFirestore.instance.collection("groups");

  Stream<QuerySnapshot> getSemesterUnits() =>
      units.where("semester", isEqualTo: 1).snapshots();
}
