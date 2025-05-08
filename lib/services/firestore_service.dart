import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Method to get tasks stream
  Stream<QuerySnapshot> getTasksStream(String uid) {
    return _db.collection('users').doc(uid).collection('tasks').snapshots();
  }

  // Method to add a task
  Future<void> addTask(String uid, String title) async {
    try {
      await _db.collection('users').doc(uid).collection('tasks').add({
        'title': title,
        'completed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception('Error adding task: $e');
    }
  }

  // Method to toggle task completion status
  Future<void> toggleTaskComplete(String uid, String taskId, bool completed) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(taskId)
          .update({'completed': completed});
    } catch (e) {
      throw Exception('Error toggling task completion: $e');
    }
  }

  // Method to delete a task
  Future<void> deleteTask(String uid, String taskId) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(taskId)
          .delete();
    } catch (e) {
      throw Exception('Error deleting task: $e');
    }
  }

  // **New Method to update task title**
  Future<void> updateTaskTitle(String uid, String taskId, String newTitle) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .doc(taskId)
          .update({'title': newTitle});
    } catch (e) {
      throw Exception('Error updating task title: $e');
    }
  }
}
