import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Welcome Back 👋")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Today’s Overview", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: 0.6), // 60% tasks done
            const SizedBox(height: 20),
            Text("Quick Tasks", style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            // Add your TaskTiles here
            ElevatedButton.icon(
              onPressed: () {}, 
              icon: Icon(Icons.add),
              label: Text("Add New Task"),
            ),
            const SizedBox(height: 20),
            Text("Motivational Quote:"),
            Text("“Success is the sum of small efforts, repeated day in and day out.”"),
          ],
        ),
      ),
    );
  }
}
