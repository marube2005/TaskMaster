import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myapp/widgets/add_task_dialog.dart'; // Make sure the path is correct

class TasksPage extends StatelessWidget {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final String uid = _auth.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text("User data not found."));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String username = userData['username'] ?? 'User';

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').doc(uid).collection('tasks').snapshots(),
          builder: (context, taskSnapshot) {
            if (taskSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final tasks = taskSnapshot.data?.docs ?? [];
            final totalTasks = tasks.length;
            final completedTasks = tasks.where((task) => task['completed'] == true).length;
            final double progress = totalTasks == 0 ? 0 : completedTasks / totalTasks;

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text("Welcome back, $username!", style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  _buildTaskSummary(progress),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => AddTaskDialog(),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text("Add New Task"),
                  ),
                  const SizedBox(height: 20),
                  const Text("Your Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  ...tasks.map((doc) {
                    final task = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      title: Text(task['title']),
                      trailing: Icon(
                        task['completed'] ? Icons.check_circle : Icons.circle_outlined,
                        color: task['completed'] ? Colors.green : Colors.grey,
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTaskSummary(double progress) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text("${(progress * 100).toInt()}% of tasks completed"),
          ],
        ),
      ),
    );
  }
}
