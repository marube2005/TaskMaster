import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:async/async.dart';

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
  List<Map<String, dynamic>> _chatMessages = [];
  bool _isGoalPlanningMode = false; // Track goal planning mode
  String? _currentGoal; // Store the user's goal for refinement
  final List<String> _motivationalQuotes = [
    "Every small step today brings you closer to your goals!",
    "You’ve got this—keep pushing forward!",
    "Stay focused and make today count!",
  ];
  final _cache = AsyncCache(const Duration(minutes: 5));
  bool _isPermissionDenied = false;

  // Gemini API details
  final String _geminiApiKey = 'AIzaSyDpn23w-LBJ8xoHEEH4P8gFf64J4vljUi4';
  final String _geminiApiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-001:generateContent';

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    var status = await Permission.microphone.status;
    if (status.isPermanentlyDenied) {
      setState(() => _isPermissionDenied = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Microphone permission is permanently denied. Please enable it in settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
    } else if (!status.isGranted) {
      await Permission.microphone.request();
    }
  }

  Future<void> _toggleListening() async {
    if (_isPermissionDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Microphone access is denied. Enable it in settings.'),
          action: SnackBarAction(
            label: 'Open Settings',
            onPressed: openAppSettings,
          ),
        ),
      );
      return;
    }

    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (status) => setState(() => _isListening = status == 'listening'),
        onError: (error) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Speech recognition error: ${error.errorMsg}')),
        ),
        finalTimeout: const Duration(seconds: 10),
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
          localeId: 'en_US',
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
      }
    } else {
      _speech.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _processInput(String input) async {
    if (input.trim().isEmpty) return;

    final timestamp = DateTime.now();
    setState(() {
      _chatMessages.add({
        'sender': 'user',
        'message': input,
        'timestamp': timestamp,
      });
    });

    // Check for exit command in goal planning mode
    if (_isGoalPlanningMode && input.toLowerCase().contains('done')) {
      setState(() {
        _isGoalPlanningMode = false;
        _currentGoal = null;
      });
      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': 'Goal planning session ended. Let me know if you want to set another goal!',
          'timestamp': timestamp,
        });
      });
      _textController.clear();
      return;
    }

    // Handle follow-up goal refinement
    if (_isGoalPlanningMode) {
      await _refineGoal(input, timestamp);
    }
    // Handle specific queries
    else if (input.toLowerCase().contains('what should i do today')) {
      await _generateTodaySuggestions();
    } else if (_isGoalPlanningTrigger(input)) {
      await _handleGoalPlanning(input, timestamp);
    } else {
      await _handleGeminiResponse(input, timestamp);
    }

    _textController.clear();
  }

  bool _isGoalPlanningTrigger(String input) {
    final lowerInput = input.toLowerCase();
    // More specific trigger conditions
    return (lowerInput.contains('set a goal') ||
        lowerInput.contains('plan a goal') ||
        lowerInput.contains('achieve') && lowerInput.contains('goal') ||
        lowerInput.contains('set') && lowerInput.contains('plan'));
  }

  Future<void> _handleGoalPlanning(String input, DateTime timestamp) async {
    String goalDescription = _extractGoal(input);
    setState(() {
      _isGoalPlanningMode = true;
      _currentGoal = goalDescription.isNotEmpty ? goalDescription : null;
    });

    String response;
    if (goalDescription.isNotEmpty) {
      response = '''
You mentioned wanting to **$goalDescription**. Let's refine it using the **SMART** framework:  
- **Specific**: Can you clarify exactly what you want to achieve? (e.g., scope or details)  
- **Measurable**: How will you track progress? (e.g., metrics or milestones)  
- **Achievable**: Is this realistic given your resources?  
- **Relevant**: Does it align with your priorities?  
- **Time-bound**: By when do you want to achieve it?  

Please provide more details, or type "done" to exit.
''';
    } else {
      response = '''
Let's plan your goal using the **SMART** framework:  
- **Specific**: What exactly do you want to achieve?  
- **Measurable**: How will you track progress?  
- **Achievable**: Is this realistic for you?  
- **Relevant**: Does it align with your values?  
- **Time-bound**: When will you complete it?  

Example: *Run a 5K in 3 months by training 3 times a week.*  
Tell me your goal, or type "done" to exit.
''';
    }

    setState(() {
      _chatMessages.add({
        'sender': 'bot',
        'message': response,
        'timestamp': timestamp,
      });
    });
  }

  String _extractGoal(String input) {
    // Simple extraction: look for phrases after "want to" or similar
    // ignore: unused_local_variable
    final lowerInput = input.toLowerCase();
    RegExp regex = RegExp(r'(?:want to|set a goal to|plan to|achieve)\s+(.+)', caseSensitive: false);
    final match = regex.firstMatch(input);
    return match != null ? match.group(1)!.trim() : '';
  }

  Future<void> _refineGoal(String input, DateTime timestamp) async {
    // Save the goal to Firestore
    final uid = _auth.currentUser!.uid;
    final goalDescription = _currentGoal ?? input;

    try {
      await _firestoreService.addGoal(uid, {
        'description': goalDescription,
        'createdAt': Timestamp.now(),
        'isCompleted': false,
      });

      final response = '''
Great! Your goal **"$goalDescription"** has been saved. Here's how it fits the **SMART** framework:  
- **Specific**: You've defined "$goalDescription".  
- **Measurable**: Consider tracking progress (e.g., weekly milestones).  
- **Achievable**: Ensure you have the resources to succeed.  
- **Relevant**: Confirm it aligns with your priorities.  
- **Time-bound**: Set a deadline (e.g., 3 months).  

Would you like to refine it further? If finished, type "done".
''';

      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': response,
          'timestamp': timestamp,
        });
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': 'Error saving goal: $e. Please try again or type "done" to exit.',
          'timestamp': timestamp,
        });
      });
    }
  }

  Future<void> _generateTodaySuggestions() async {
    final uid = _auth.currentUser!.uid;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final timestamp = DateTime.now();

    try {
      final habits = await _cache.fetch(() async {
        return await _retryFirestoreOperation(
          () => _firestoreService.getHabitsStream(uid).first,
        );
      });

      final tasks = await _cache.fetch(() async {
        return await _retryFirestoreOperation(
          () => _firestoreService.getTasksStream(uid).first,
        );
      });

      final goals = await _cache.fetch(() async {
        return await _retryFirestoreOperation(
          () => _firestoreService.getGoalsStream(uid).first,
        );
      });

      final habitsList = habits.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      final todayTasks = tasks.docs.where((doc) {
        final task = doc.data() as Map<String, dynamic>;
        final Timestamp? timestamp = task['createdAt'];
        final DateTime? createdAt = timestamp?.toDate();
        return createdAt != null &&
            createdAt.year == today.year &&
            createdAt.month == today.month &&
            createdAt.day == today.day &&
            task['completed'] != true;
      }).toList();

      final activeGoals = goals.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((goal) => goal['isCompleted'] != true)
          .toList();

      List<String> taskSuggestions = [];
      if (habitsList.isNotEmpty) {
        taskSuggestions
            .addAll(habitsList.map((habit) => "Work on your ${habit['name']} habit."));
      }
      if (activeGoals.isNotEmpty) {
        taskSuggestions
            .addAll(activeGoals.map((goal) => "Make progress on: ${goal['description']}"));
      }
      if (habitsList.isEmpty && activeGoals.isEmpty) {
        taskSuggestions.addAll([
          'Try a 10-minute workout.',
          'Read a chapter of a book.',
          'Meditate for 5 minutes.',
        ]);
      }
      taskSuggestions.addAll(todayTasks.map((task) => 'Complete: ${task['title']}'));

      final breakIdeas = [
        'Take a 5-minute walk outside.',
        'Do a quick stretch.',
        'Listen to your favorite song.',
      ];
      final motivation =
          _motivationalQuotes[DateTime.now().millisecondsSinceEpoch % _motivationalQuotes.length];

      final response = '''
**Today's Suggestions**  
**Tasks**  
${taskSuggestions.map((t) => '- $t').join('\n')}  

**Break Ideas**  
${breakIdeas.map((b) => '- $b').join('\n')}  

**Motivation**  
*$motivation*
''';

      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': response,
          'timestamp': timestamp,
        });
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': 'Error fetching suggestions: $e. Please try again.',
          'timestamp': timestamp,
        });
      });
    }
  }

  Future<void> _handleGeminiResponse(String input, DateTime timestamp) async {
    try {
      final response = await _retryApiOperation(() async {
        final uri = Uri.parse('$_geminiApiUrl?key=$_geminiApiKey');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': input}
                ]
              }
            ],
            'generationConfig': {
              'maxOutputTokens': 150,
            },
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]['content']['parts'][0]['text'] ??
              'I’m not sure how to respond. Try again!';
          return text;
        } else {
          throw Exception('Gemini API error: ${response.statusCode} - ${response.body}');
        }
      });

      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': response,
          'timestamp': timestamp,
        });
      });
    } catch (e) {
      setState(() {
        _chatMessages.add({
          'sender': 'bot',
          'message': 'Error contacting Gemini API: $e. Please try again.',
          'timestamp': timestamp,
        });
      });
    }
  }

  Future<T> _retryFirestoreOperation<T>(Future<T> Function() operation) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw Exception('Firestore operation failed after $maxRetries attempts');
  }

  Future<T> _retryApiOperation<T>(Future<T> Function() operation) async {
    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
    throw Exception('API operation failed after $maxRetries attempts');
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
              primary: false,
              padding: const EdgeInsets.all(8.0),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final message = _chatMessages[index];
                final isUser = message['sender'] == 'user';
                final timestamp = (message['timestamp'] as DateTime);
                final formattedTime = DateFormat('HH:mm').format(timestamp);

                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        isUser
                            ? Semantics(
                                label: 'User: ${message['message']}',
                                child: Text(
                                  message['message']!,
                                  style: const TextStyle(fontSize: 16.0),
                                ),
                              )
                            : Semantics(
                                label: 'Bot: ${message['message']}',
                                child: MarkdownBody(
                                  data: message['message']!,
                                  styleSheet: MarkdownStyleSheet(
                                    p: const TextStyle(fontSize: 16.0),
                                    strong: const TextStyle(fontWeight: FontWeight.bold),
                                    em: const TextStyle(fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 4.0),
                        Semantics(
                          label: 'Sent at $formattedTime',
                          child: Text(
                            formattedTime,
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isListening ? Icons.mic : Icons.mic_none,
                          color: _isListening ? Colors.red : Colors.blue,
                        ),
                        onPressed: _toggleListening,
                        tooltip: 'Voice Input',
                      ),
                    ),
                    onSubmitted: (_) => _processInput(_textController.text),
                 //   accessKey: const AccessKey('messageInput'),
                  ),
                ),
                const SizedBox(width: 8.0),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: () => _processInput(_textController.text),
                  tooltip: 'Send Message',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}