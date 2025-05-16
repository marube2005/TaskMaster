import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:async/async.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class InsightsPage extends StatefulWidget {
  const InsightsPage({super.key});

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final _cache = AsyncCache(const Duration(minutes: 5));
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, int> _weeklyTasks = {};
  Map<String, int> _monthlyTasks = {};
  Map<String, int> _categoryProductivity = {};
  List<String> _improvementSuggestions = [];
  List<String> _aiHabitSuggestions = [];
  List<FlSpot> _dailyCompletionSpots = [];

  // Hypothetical Grok API details (replace with actual values)
  final String _grokApiKey = 'YOUR_GROK_API_KEY';
  final String _grokApiUrl = 'https://api.x.ai/grok/v1/chat';

  @override
  void initState() {
    super.initState();
    _fetchInsights();
  }

  Future<void> _fetchInsights() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No user signed in.';
      });
      return;
    }

    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = now.month < 12
          ? DateTime(now.year, now.month + 1, 0)
          : DateTime(now.year + 1, 1, 0);
      final startOfPastMonth = startOfMonth.subtract(const Duration(days: 30));

      // Fetch tasks with caching and retry logic
      final tasksSnapshot = await _cache.fetch(() async {
        return await _retryFirestoreOperation(
          () => _firestoreService.getTasksStream(uid).first,
        );
      });

      final tasks = tasksSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Process weekly tasks (by day)
      final weeklyTasks = <String, int>{};
      for (var i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayKey = DateFormat('EEEE').format(day);
        weeklyTasks[dayKey] = 0;
      }
      for (var task in tasks.where((t) => t['completed'] == true)) {
        final Timestamp? timestamp = task['completedAt'];
        final DateTime? completedAt = timestamp?.toDate();
        if (completedAt != null &&
            completedAt.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
            completedAt.isBefore(now.add(const Duration(seconds: 1)))) {
          final dayKey = DateFormat('EEEE').format(completedAt);
          weeklyTasks[dayKey] = (weeklyTasks[dayKey] ?? 0) + 1;
        }
      }

      // Process monthly tasks (by week)
      final monthlyTasks = <String, int>{};
      final weeksInMonth = (endOfMonth.day / 7).ceil();
      for (var i = 1; i <= weeksInMonth; i++) {
        monthlyTasks['Week $i'] = 0;
      }
      for (var task in tasks.where((t) => t['completed'] == true)) {
        final Timestamp? timestamp = task['completedAt'];
        final DateTime? completedAt = timestamp?.toDate();
        if (completedAt != null &&
            completedAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            completedAt.isBefore(endOfMonth.add(const Duration(seconds: 1)))) {
          final weekNumber = ((completedAt.day - 1) / 7).floor() + 1;
          final weekKey = 'Week $weekNumber';
          monthlyTasks[weekKey] = (monthlyTasks[weekKey] ?? 0) + 1;
        }
      }

      // Process productivity by category
      final categoryProductivity = <String, int>{};
      for (var task in tasks.where((t) => t['completed'] == true)) {
        final category = task['category']?.toString() ?? 'Uncategorized';
        categoryProductivity[category] = (categoryProductivity[category] ?? 0) + 1;
      }

      // Process daily completion over time (past 30 days)
      final dailyCompletions = <DateTime, int>{};
      for (var i = 0; i < 30; i++) {
        final day = startOfMonth.subtract(Duration(days: i));
        dailyCompletions[DateTime(day.year, day.month, day.day)] = 0;
      }
      for (var task in tasks.where((t) => t['completed'] == true)) {
        final Timestamp? timestamp = task['completedAt'];
        final DateTime? completedAt = timestamp?.toDate();
        if (completedAt != null &&
            completedAt.isAfter(startOfPastMonth.subtract(const Duration(seconds: 1)))) {
          final dayKey = DateTime(completedAt.year, completedAt.month, completedAt.day);
          dailyCompletions[dayKey] = (dailyCompletions[dayKey] ?? 0) + 1;
        }
      }
     final dailyCompletionSpots = dailyCompletions.entries
    .toList()
    .asMap()
    .entries
    .map((entry) {
      final index = entry.key;
      final mapEntry = entry.value; // mapEntry is MapEntry<DateTime, double> or int
      return FlSpot(index.toDouble(), mapEntry.value.toDouble());
    })
    .toList()
  ..sort((a, b) => a.x.compareTo(b.x));


      // Generate improvement suggestions
      final improvementSuggestions = <String>[];
      final lowCompletionDays = weeklyTasks.entries
          .where((e) => e.value == 0 || e.value < (weeklyTasks.values.reduce((a, b) => a + b) / 7))
          .map((e) => e.key)
          .toList();
      if (lowCompletionDays.isNotEmpty) {
        improvementSuggestions.add(
          'You have low task completion on ${lowCompletionDays.join(", ")}. Try scheduling tasks earlier on these days.',
        );
      }
      if (categoryProductivity.isNotEmpty) {
        final topCategory = categoryProductivity.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;
        improvementSuggestions.add(
          'You’re highly productive in $topCategory. Consider allocating more time to similar tasks.',
        );
      }

      // Fetch AI-generated habit suggestions
      final aiHabits = await _fetchAIHabits(categoryProductivity);

      setState(() {
        _weeklyTasks = weeklyTasks;
        _monthlyTasks = monthlyTasks;
        _categoryProductivity = categoryProductivity;
        _improvementSuggestions = improvementSuggestions;
        _aiHabitSuggestions = aiHabits;
        _dailyCompletionSpots = dailyCompletionSpots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching insights: $e';
      });
    }
  }

  Future<List<String>> _fetchAIHabits(Map<String, int> categoryProductivity) async {
    try {
      final topCategories = categoryProductivity.entries
          .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
      final prompt = '''
Based on the user's task categories: ${topCategories.take(3).map((e) => '${e.key}: ${e.value} tasks').join(', ')},
suggest 3 new habits to improve their productivity. Provide each habit as a concise sentence.
Example: "Schedule 30 minutes daily for focused study to boost academic performance."
''';

      final response = await _retryApiOperation(() async {
        final response = await http.post(
          Uri.parse(_grokApiUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_grokApiKey',
          },
          body: jsonEncode({
            'prompt': prompt,
            'max_tokens': 150,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return (data['response'] as String).split('\n').where((s) => s.trim().isNotEmpty).toList();
        } else {
          throw Exception('Grok API error: ${response.statusCode}');
        }
      });

      return response.take(3).toList();
    } catch (e) {
      return ['Error generating habits: $e. Try again later.'];
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

  Widget _buildCategoryBarChart() {
    final maxTasks = _categoryProductivity.values.fold<int>(0, (a, b) => a > b ? a : b);
    final entriesList = _categoryProductivity.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)); // Sort by task count
    final barGroups = entriesList
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final count = entry.value.value.toDouble();
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count,
                color: Colors.blue,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        })
        .toList();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxTasks + 1).toDouble(),
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                  semanticsLabel: '${value.toInt()} tasks',
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final category = entriesList[value.toInt()].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      category.length > 10
                          ? '${category.substring(0, 7)}...'
                          : category,
                      style: const TextStyle(fontSize: 12),
                      textAlign: TextAlign.center,
                      semanticsLabel: 'Category: $category',
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final category = entriesList[group.x.toInt()].key;
                return BarTooltipItem(
                  '$category\n${rod.toY.toInt()} tasks',
                  const TextStyle(color: Colors.white),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionLineChart() {
    final maxTasks = _dailyCompletionSpots.fold<double>(
        0, (a, b) => a > b.y ? a : b.y);
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              spots: _dailyCompletionSpots,
              isCurved: true,
              color: Colors.blue,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: false),
            ),
          ],
          minY: 0,
          maxY: (maxTasks + 1).toDouble(),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                  semanticsLabel: '${value.toInt()} tasks',
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  final dayIndex = value.toInt();
                  if (dayIndex % 5 != 0) return const Text('');
                  final date = DateTime.now().subtract(Duration(days: 29 - dayIndex));
                  return Text(
                    DateFormat('MM/dd').format(date),
                    style: const TextStyle(fontSize: 12),
                    semanticsLabel: DateFormat('MMMM d').format(date),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                final dayIndex = spot.x.toInt();
                final date = DateTime.now().subtract(Duration(days: 29 - dayIndex));
                return LineTooltipItem(
                  '${DateFormat('MM/dd').format(date)}\n${spot.y.toInt()} tasks',
                  const TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("No user signed in.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Insights"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                        semanticsLabel: 'Error: $_errorMessage',
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchInsights,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Weekly Completed Tasks',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Weekly Completed Tasks',
                      ),
                      const SizedBox(height: 8),
                      ..._weeklyTasks.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '${entry.key}: ${entry.value} task${entry.value == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 16),
                            semanticsLabel:
                                '${entry.key}: ${entry.value} task${entry.value == 1 ? '' : 's'}',
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Monthly Completed Tasks',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Monthly Completed Tasks',
                      ),
                      const SizedBox(height: 8),
                      ..._monthlyTasks.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '${entry.key}: ${entry.value} task${entry.value == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 16),
                            semanticsLabel:
                                '${entry.key}: ${entry.value} task${entry.value == 1 ? '' : 's'}',
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'Top Task Categories',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Top Task Categories',
                      ),
                      const SizedBox(height: 8),
                      ..._categoryProductivity.entries
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                            final index = entry.key;
                            final category = entry.value.key;
                            final count = entry.value.value;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4.0),
                              child: Text(
                                '${index + 1}. $category: $count task${count == 1 ? '' : 's'}',
                                style: const TextStyle(fontSize: 16),
                                semanticsLabel:
                                    'Rank ${index + 1}: $category with $count task${count == 1 ? '' : 's'}',
                              ),
                            );
                          }),
                      const SizedBox(height: 8),
                      _buildCategoryBarChart(),
                      const SizedBox(height: 16),
                      const Text(
                        'Task Completion Over Time (Past 30 Days)',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Task Completion Over Time, Past 30 Days',
                      ),
                      const SizedBox(height: 8),
                      _buildCompletionLineChart(),
                      const SizedBox(height: 16),
                      const Text(
                        'Improvement Suggestions',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'Improvement Suggestions',
                      ),
                      const SizedBox(height: 8),
                      ..._improvementSuggestions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final suggestion = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '${index + 1}. $suggestion',
                            style: const TextStyle(fontSize: 16),
                            semanticsLabel: 'Suggestion ${index + 1}: $suggestion',
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                      const Text(
                        'AI-Generated Habit Suggestions',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        semanticsLabel: 'AI-Generated Habit Suggestions',
                      ),
                      const SizedBox(height: 8),
                      ..._aiHabitSuggestions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final habit = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Text(
                            '${index + 1}. $habit',
                            style: const TextStyle(fontSize: 16),
                            semanticsLabel: 'Habit ${index + 1}: $habit',
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }
}