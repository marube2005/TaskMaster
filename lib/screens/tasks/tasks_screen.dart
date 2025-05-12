import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:myapp/widgets/add_task_dialog.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  String _filter = 'All'; // Filter state: All, Today, Upcoming, Completed

  @override
  Widget build(BuildContext context) {
    final String uid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Tasks"), centerTitle: true),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
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
            stream: _firestoreService.getTasksStream(uid),
            builder: (context, taskSnapshot) {
              if (taskSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (taskSnapshot.hasError) {
                return const Center(child: Text("Error loading tasks."));
              }

              final tasks = taskSnapshot.data?.docs ?? [];
              final filteredTasks = _filterTasks(tasks);
              final totalTasks = filteredTasks.length;
              final completedTasks =
                  filteredTasks.where((task) => task['completed'] == true).length;
              final double progress = totalTasks == 0 ? 0 : completedTasks / totalTasks;

              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    Text(
                      "Welcome back, $username!",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 20),
                    _buildTaskSummary(totalTasks, completedTasks, progress),
                    const SizedBox(height: 20),
                    _buildFilterButtons(),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showAddTaskDialog(context, uid),
                      icon: const Icon(Icons.add),
                      label: const Text("Add New Task"),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Your Tasks",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    if (filteredTasks.isEmpty)
                      const Center(child: Text("No tasks available."))
                    else
                      ...filteredTasks
                          .map((doc) => _buildTaskTile(context, uid, doc))
                          .toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTaskSummary(int totalTasks, int completedTasks, double progress) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Task Progress",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 10),
            Text('$completedTasks of $totalTasks tasks completed (${(progress * 100).toInt()}%)'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: [
        _buildFilterButton('All'),
        _buildFilterButton('Today'),
        _buildFilterButton('Upcoming'),
        _buildFilterButton('Completed'),
      ],
    );
  }

  Widget _buildFilterButton(String filter) {
    return ElevatedButton(
      onPressed: () => setState(() => _filter = filter),
      style: ElevatedButton.styleFrom(
        backgroundColor: _filter == filter ? Colors.blue : Colors.grey[300],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minimumSize: const Size(80, 36),
      ),
      child: Text(
        filter,
        style: const TextStyle(fontSize: 14),
      ),
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
          IconButton(
            icon: Icon(
              task['completed'] ? Icons.check_circle : Icons.circle_outlined,
              color: task['completed'] ? Colors.green : Colors.grey,
            ),
            onPressed: () async {
              await _firestoreService.toggleTaskComplete(uid, doc.id, !(task['completed'] == true));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(task['completed'] == true ? 'Task marked incomplete' : 'Task completed'),
                ),
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

  List<QueryDocumentSnapshot> _filterTasks(List<QueryDocumentSnapshot> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));

    return tasks.where((doc) {
      final task = doc.data() as Map<String, dynamic>;
      final Timestamp? timestamp = task['createdAt'];
      final DateTime? createdAt = timestamp?.toDate();
      final bool isCompleted = task['completed'] == true;

      switch (_filter) {
        case 'Today':
          return createdAt != null &&
              createdAt.year == today.year &&
              createdAt.month == today.month &&
              createdAt.day == today.day;
        case 'Upcoming':
          return createdAt != null && createdAt.isAfter(tomorrow);
        case 'Completed':
          return isCompleted;
        default:
          return true;
      }
    }).toList();
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
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task updated')));
      }
    } else if (action == 'delete' || action == 'archive') {
      await _firestoreService.deleteTask(uid, taskId);
      // ignore: use_build_context_synchronously
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
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Action'),
        content: Text('What would you like to do with "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('delete'),
            child: const Text('Delete'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('archive'),
            child: const Text('Archive'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (action != null) {
      await _firestoreService.deleteTask(uid, taskId);
      // ignore: use_build_context_synchronously
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
}