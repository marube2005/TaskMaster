import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart'; // Firestore service
import 'package:myapp/widgets/add_task_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user signed in.")));
    }

    final String uid = user.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Home"), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading user data."));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("User data not found."));
          }

          final userData = snapshot.data!.data() as Map<String, dynamic>;
          final String username = userData['username'] ?? 'User';

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getTasksStream(uid),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (taskSnapshot.hasError) {
                return const Center(child: Text("Error loading tasks."));
              }

              final tasks = taskSnapshot.data?.docs ?? [];
              final totalTasks = tasks.length;
              final completedTasks =
                  tasks.where((task) => task['completed'] == true).length;
              final double progress =
                  totalTasks == 0 ? 0 : completedTasks / totalTasks;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Text(
                      "Welcome back, $username!",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildTaskSummary(progress),
                    const SizedBox(height: 20),
                    _buildQuoteCard(uid),
                    const SizedBox(height: 20),
                    const Text(
                      "Your Tasks",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...tasks.map((doc) {
                      final task = doc.data() as Map<String, dynamic>;
                      final Timestamp? timestamp = task['createdAt'];
                      final DateTime? createdAt = timestamp?.toDate();

                      return ListTile(
                        title: Text(task['title'] ?? 'Untitled'),
                        subtitle:
                            createdAt != null
                                ? Text(
                                  'Created on: ${createdAt.toLocal().toString().split('.')[0]}',
                                )
                                : const Text('Created on: N/A'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: task['completed'] == true,
                              onChanged: (bool? value) async {
                                final updatedCompleted = value ?? false;
                                await _firestoreService.toggleTaskComplete(
                                  uid,
                                  doc.id,
                                  updatedCompleted,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      updatedCompleted
                                          ? 'Task marked complete'
                                          : 'Task marked incomplete',
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                await _firestoreService.deleteTask(uid, doc.id);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Task "${task['title']}" deleted',
                                    ),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        await _firestoreService.addTask(
                                          uid,
                                          task['title'],
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert),
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  final controller = TextEditingController(
                                    text: task['title'],
                                  );
                                  final newTitle = await showDialog<String>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Edit Task'),
                                      content: TextField(
                                        controller: controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Task title',
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('Cancel'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(
                                                  controller.text),
                                          child: const Text('Save'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (newTitle != null &&
                                      newTitle.trim().isNotEmpty &&
                                      newTitle.trim() != task['title']) {
                                    await _firestoreService.updateTaskTitle(
                                      uid,
                                      doc.id,
                                      newTitle.trim(),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Task updated')),
                                    );
                                  }
                                } else if (value == 'delete') {
                                  await _firestoreService.deleteTask(uid, doc.id);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Task "${task['title']}" deleted'),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () async {
                                          await _firestoreService.addTask(
                                            uid,
                                            task['title'],
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                        onLongPress: () async {
                          await _firestoreService.deleteTask(uid, doc.id);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Task "${task['title']}" deleted'),
                              action: SnackBarAction(
                                label: 'Undo',
                                onPressed: () async {
                                  await _firestoreService.addTask(
                                    uid,
                                    task['title'],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final String? taskTitle = await showDialog<String>(
            context: context,
            builder: (BuildContext dialogContext) => const AddTaskDialog(),
          );

          if (taskTitle != null && taskTitle.trim().isNotEmpty) {
            try {
              await _firestoreService.addTask(uid, taskTitle.trim());
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Task added successfully!')),
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add task: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        // ignore: sort_child_properties_last
        child: const Icon(Icons.add),
        tooltip: 'Add Task',
      ),
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
            const Text(
              "Today's Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text('${(progress * 100).toInt()}% of tasks completed'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('meta')
              .doc('daily')
              .get(),
      builder: (context, snapshot) {
        final quote =
            snapshot.hasData && snapshot.data!.exists
                ? (snapshot.data!.data() as Map<String, dynamic>)['quote'] ?? 
                    '“Take a break. Reconnect.”'
                : '“Take a break. Reconnect.”';

        return Card(
          color: Colors.lightBlue[50],
          elevation: 3,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              quote,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}
