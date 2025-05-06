import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

class AddTaskDialog extends StatefulWidget {
  @override
  _AddTaskDialogState createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<AddTaskDialog> {
  final _controller = TextEditingController();
  bool _isLoading = false;

  void _addTask() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() => _isLoading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      // Save task to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('tasks')
          .add({
            'title': _controller.text.trim(),
            'completed': false,
            'createdAt': Timestamp.now(),
          });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task added successfully!')),
      );
      
      // Pop the dialog to go back to the home page
      Navigator.of(context).pop();

    } catch (e) {
      // Handle errors, show failure message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add task. Please try again.')),
      );
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Task'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(hintText: 'Enter task title'),
        autofocus: true,
        onSubmitted: (_) => _addTask(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _addTask,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Add'),
        ),
      ],
    );
  }
}
