import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Method to get tasks stream
  Stream<QuerySnapshot> getTasksStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('tasks')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getHabitsStream(String uid) {
    return _db.collection('users').doc(uid).collection('habits').snapshots();
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
  Future<void> toggleTaskComplete(
    String uid,
    String taskId,
    bool completed,
  ) async {
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

  // Add a goal for a user
  Future<void> addGoal(String uid, Map<String, dynamic> goalData) async {
    await _db.collection('users').doc(uid).collection('goals').add(goalData);
  }

  // Get goals stream for a user
  Stream<QuerySnapshot> getGoalsStream(String uid) {
    return _db.collection('users').doc(uid).collection('goals').snapshots();
  }

  // Update a goal for a user
  Future<void> updateGoal(
    String uid,
    String goalId,
    Map<String, dynamic> goalData,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .update(goalData);
  }

  // Delete a goal for a user
  Future<void> deleteGoal(String uid, String goalId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('goals')
        .doc(goalId)
        .delete();
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
  Future<void> updateTaskTitle(
    String uid,
    String taskId,
    String newTitle,
  ) async {
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
