import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final SpeechToText _speech = SpeechToText();
  final TextEditingController _textController = TextEditingController();
  bool _isListening = false;
  String _recognizedText = '';
  List<Map<String, String>> _chatMessages = [];
  final List<String> _motivationalQuotes = [
    "Every small step today brings you closer to your goals!",
    "You’ve got this—keep pushing forward!",
    "Stay focused and make today count!",
  ];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.microphone.request();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => setState(() => _isListening = status == 'listening'),
        onError: (error) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition error: ${error.errorMsg}')),
        ),
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _recognizedText = result.recognizedWords;
              if (result.finalResult) {
                _processInput(_recognizedText);
                _speech.stop();
              }
            });
          },
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  void _processInput(String input) {
    if (input.trim().isEmpty) return;

    // Add user message to chat
    setState(() {
      _chatMessages.add({'sender': 'user', 'message': input});
    });

    // Handle "What should I do today?" or goal planning
    if (input.toLowerCase().contains('what should i do today')) {
      _generateTodaySuggestions();
    } else {
      _handleGoalPlanning(input);
    }

    // Clear text input if used
    _textController.clear();
  }

  Future<void> _generateTodaySuggestions() async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Fetch habits
    final habitsSnapshot = await _firestoreService.getHabitsStream(uid).first;
    final habits = habitsSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // Fetch today's incomplete tasks
    final tasksSnapshot = await _firestoreService.getTasksStream(uid).first;
    final todayTasks = tasksSnapshot.docs.where((doc) {
      final task = doc.data() as Map<String, dynamic>;
      final Timestamp? timestamp = task['createdAt'];
      final DateTime? createdAt = timestamp?.toDate();
      return createdAt != null &&
          createdAt.year == today.year &&
          createdAt.month == today.month &&
          createdAt.day == today.day &&
          task['completed'] != true;
    }).toList();

    // Generate suggestions
    List<String> tasks = [];
    if (habits.isNotEmpty) {
      tasks.addAll(habits.map((habit) => "Work on your ${habit['name']} habit."));
    } else {
      tasks.addAll([
        'Try a 10-minute workout.',
        'Read a chapter of a book.',
        'Meditate for 5 minutes.',
      ]);
    }
    tasks.addAll(todayTasks.map((task) => 'Complete: ${task['title']}'));

    final breakIdeas = [
      'Take a 5-minute walk outside.',
      'Do a quick stretch.',
      'Listen to your favorite song.',
    ];
    final motivation = _motivationalQuotes[DateTime.now().millisecondsSinceEpoch % _motivationalQuotes.length];

    final response = '''
**Today's Suggestions:**
**Tasks:**
${tasks.map((t) => '- $t').join('\n')}

**Break Ideas:**
${breakIdeas.map((b) => '- $b').join('\n')}

**Motivation:**
$motivation
''';

    setState(() {
      _chatMessages.add({'sender': 'bot', 'message': response});
    });
  }

  void _handleGoalPlanning(String input) {
    String response;
    if (input.toLowerCase().contains('goal') || input.toLowerCase().contains('plan')) {
      response = '''
Let's plan your goal! Try the SMART framework:
- **Specific**: What exactly do you want to achieve?
- **Measurable**: How will you track progress?
- **Achievable**: Is this realistic for you?
- **Relevant**: Does it align with your values?
- **Time-bound**: When will you complete it?

Example: "Run a 5K in 3 months by training 3 times a week."
Tell me your goal, and I’ll help refine it!
''';
    } else {
      response = 'I’m here to help! Try asking about your goals or what to do today.';
    }

    setState(() {
      _chatMessages.add({'sender': 'bot', 'message': response});
    });
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text("No user signed in.")));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Chatbot"), centerTitle: true),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                final isUser = message['sender'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      message['message']!,
                      style: const TextStyle(fontSize: 16.0),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message or use voice...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _processInput,
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: _isListening ? Colors.red : Colors.blue,
                  ),
                  onPressed: _toggleListening,
                  tooltip: 'Voice Input',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}