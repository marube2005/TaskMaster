import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/widgets/add_task_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Sample list of motivational quotes
  final List<String> _quotes = [
    "“The secret of getting ahead is getting started.” – Mark Twain",
    "“You don’t have to be great to start, but you have to start to be great.” – Zig Ziglar",
    "“The way to get started is to quit talking and begin doing.” – Walt Disney",
    "“Don’t watch the clock; do what it does. Keep going.” – Sam Levenson",
    "“Success is not the absence of obstacles, but the courage to push through them.”",
  ];

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
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Error loading user data."));
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
              // Filter tasks to only include those created today
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final todayTasks = tasks.where((doc) {
                final task = doc.data() as Map<String, dynamic>;
                final Timestamp? timestamp = task['createdAt'];
                final DateTime? createdAt = timestamp?.toDate();
                return createdAt != null &&
                    createdAt.year == today.year &&
                    createdAt.month == today.month &&
                    createdAt.day == today.day;
              }).toList();

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Text(
                      "Welcome back, $username!",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildDailyTaskSummary(tasks),
                    const SizedBox(height: 20),
                    _buildQuoteCard(uid),
                    const SizedBox(height: 20),
                    const Text(
                      "Today's Tasks",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (todayTasks.isEmpty)
                      const Center(child: Text("No tasks for today. Add some to get started!"))
                    else
                      ...todayTasks.map((doc) => _buildTaskTile(context, uid, doc)).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context, uid),
        child: const Icon(Icons.add),
        tooltip: 'Add Task',
      ),
    );
  }

  Widget _buildDailyTaskSummary(List<QueryDocumentSnapshot> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayTasks = tasks.where((doc) {
      final task = doc.data() as Map<String, dynamic>;
      final Timestamp? timestamp = task['createdAt'];
      final DateTime? createdAt = timestamp?.toDate();
      return createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day;
    }).toList();

    final totalTodayTasks = todayTasks.length;
    final completedTodayTasks = todayTasks.where((task) => task['completed'] == true).length;
    final motivationalMessage = totalTodayTasks == 0
        ? "No tasks for today. Add some to get started!"
        : completedTodayTasks == totalTodayTasks && totalTodayTasks > 0
            ? "Great job! You've completed all tasks for today!"
            : "Keep going! You've got this!";

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Tasks",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.task_alt, color: Colors.blue, size: 24),
                const SizedBox(width: 8),
                Text(
                  "$completedTodayTasks of $totalTodayTasks tasks completed",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              motivationalMessage,
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteCard(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('meta')
          .doc('daily_quote')
          .get(),
      builder: (context, snapshot) {
        String quote = _quotes[DateTime.now().millisecondsSinceEpoch % _quotes.length];
        DateTime? lastUpdated;

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          quote = data['quote'] ?? quote;
          final Timestamp? timestamp = data['lastUpdated'];
          lastUpdated = timestamp?.toDate();
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        if (lastUpdated == null || lastUpdated.isBefore(today)) {
          quote = _quotes[now.millisecondsSinceEpoch % _quotes.length];
          FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('meta')
              .doc('daily_quote')
              .set({
            'quote': quote,
            'lastUpdated': Timestamp.now(),
          });
        }

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

  Widget _buildTaskTile(BuildContext context, String uid, QueryDocumentSnapshot doc) {
    final task = doc.data() as Map<String, dynamic>;
    final Timestamp? timestamp = task['createdAt'];
    final DateTime? createdAt = timestamp?.toDate();

    return ListTile(
      title: Text(task['title'] ?? 'Untitled'),
      subtitle: createdAt != null
          ? Text('Created: ${createdAt.toLocal().toString().split('.')[0]}')
          : const Text('Created: N/A'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(
            value: task['completed'] == true,
            onChanged: (value) async {
              await _firestoreService.toggleTaskComplete(uid, doc.id, value ?? false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(value ?? false ? 'Task completed' : 'Task marked incomplete')),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleTaskAction(context, uid, doc.id, task['title'], value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
            ],
          ),
        ],
      ),
      onLongPress: () => _handleLongPress(context, uid, doc.id, task['title']),
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context, String uid) async {
    final String? taskTitle = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) => const AddTaskDialog(),
    );

    if (taskTitle != null && taskTitle.trim().isNotEmpty) {
      try {
        await _firestoreService.addTask(uid, taskTitle.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task added successfully!')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add task: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _handleTaskAction(
      BuildContext context, String uid, String taskId, String title, String action) async {
    if (action == 'edit') {
      final controller = TextEditingController(text: title);
      final newTitle = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Edit Task'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Task title'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Save'),
            ),
          ],
        ),
      );

      if (newTitle != null && newTitle.trim().isNotEmpty && newTitle.trim() != title) {
        await _firestoreService.updateTaskTitle(uid, taskId, newTitle.trim());
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated')));
      }
    } else if (action == 'delete' || action == 'archive') {
      await _firestoreService.deleteTask(uid, taskId);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task "$title" ${action == 'delete' ? 'deleted' : 'archived'}'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async => await _firestoreService.addTask(uid, title),
          ),
        ),
      );
    }
  }

  Future<void> _handleLongPress(BuildContext context, String uid, String taskId, String title) async {
    await _firestoreService.deleteTask(uid, taskId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task "$title" deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async => await _firestoreService.addTask(uid, title),
        ),
      ),
    );
  }
}