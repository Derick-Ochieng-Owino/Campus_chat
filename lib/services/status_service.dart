import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/status_model.dart';

class StatusService {
  final _db = FirebaseFirestore.instance;

  Stream<List<StatusModel>> activeStatuses() {
    final now = Timestamp.now();
    return _db
        .collection('statuses')
        .where('expiresAt', isGreaterThan: now)
        .snapshots()
        .map((s) => s.docs.map(StatusModel.fromDoc).toList());
  }

  Future<void> markViewed(String statusId, String userId) async {
    await _db
        .collection('statuses')
        .doc(statusId)
        .collection('views')
        .doc(userId)
        .set({'viewedAt': FieldValue.serverTimestamp()});
  }
}
