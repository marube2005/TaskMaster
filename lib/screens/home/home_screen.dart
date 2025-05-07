import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/widgets/bottom_navbar.dart'; // Ensure your widget is named correctly
import 'package:myapp/widgets/custom_input.dart'; // Ensure your widget is named correctly
import 'package:myapp/widgets/add_task_dialog.dart'; // Ensure your widget is named correctly

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    // You can add navigation logic here if needed.
  }

  @override
  Widget build(BuildContext context) {
    final String uid = _auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
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
                    _buildQuoteCard(uid),
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
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AddTaskDialog(),
          );
        },
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

  Widget _buildQuoteCard(String uid) {
    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('users').doc(uid).collection('meta').doc('daily').get(),
      builder: (context, snapshot) {
        final quote = snapshot.hasData && snapshot.data!.exists
            ? (snapshot.data!.data() as Map<String, dynamic>)['quote']
            : "“Take a break. Reconnect.”";

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
