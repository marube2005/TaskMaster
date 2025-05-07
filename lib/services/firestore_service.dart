import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Add a task for a specific user
  Future<void> addTask(String uid, String title) async {
    await _db.collection('tasks').doc(uid).collection('userTasks').add({
      'title': title,
      'createdAt': FieldValue.serverTimestamp(),
      'completed': false,
    });
  }

  // Get task stream for user
  Stream<QuerySnapshot> getTasksStream(String uid) {
    return _db
      .collection('tasks')
      .doc(uid)
      .collection('userTasks')
      .orderBy('createdAt', descending: true)
      .snapshots();
  }

  // Mark task complete/incomplete
  Future<void> toggleTaskComplete(String uid, String taskId, bool currentStatus) async {
    await _db.collection('tasks').doc(uid).collection('userTasks').doc(taskId).update({
      'completed': !currentStatus,
    });
  }

  // Delete task
  Future<void> deleteTask(String uid, String taskId) async {
    await _db.collection('tasks').doc(uid).collection('userTasks').doc(taskId).delete();
  }
}
