import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:myapp/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:async/async.dart';

class InsightsPage extends StatefulWidget {
  const InsightsPage({Key? key}) : super(key: key);

  @override
  State<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends State<InsightsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final _cache = AsyncCache(const Duration(minutes: 5)); // Cache for 5 minutes
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, int> _weeklyTasks = {};
  Map<String, int> _monthlyTasks = {};
  Map<String, int> _categoryProductivity = {};

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

      // Fetch tasks with caching and retry logic
      final tasksSnapshot = await _cache.fetch(() async {
        return await _retryFirestoreOperation(
          () => _firestoreService.getTasksStream(uid).first,
        );
      });

      final tasks = tasksSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .where((task) => task['completed'] == true)
          .toList();

      // Process weekly tasks (by day)
      final weeklyTasks = <String, int>{};
      for (var i = 0; i < 7; i++) {
        final day = startOfWeek.add(Duration(days: i));
        final dayKey = DateFormat('EEEE').format(day); // e.g., Monday
        weeklyTasks[dayKey] = 0;
      }
      for (var task in tasks) {
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
      for (var task in tasks) {
        final Timestamp? timestamp = task['completedAt'];
        final DateTime? completedAt = timestamp?.toDate();
        if (completedAt != null &&
            completedAt.isAfter(startOfMonth.subtract(const Duration(seconds: 1))) &&
            completedAt.isBefore(endOfMonth.add(const Duration(seconds: 1)))) {
          final weekNumber =
              ((completedAt.day - 1) / 7).floor() + 1; // 1-based week
          final weekKey = 'Week $weekNumber';
          monthlyTasks[weekKey] = (monthlyTasks[weekKey] ?? 0) + 1;
        }
      }

      // Process productivity by category
      final categoryProductivity = <String, int>{};
      for (var task in tasks) {
        final category = task['category']?.toString() ?? 'Uncategorized';
        categoryProductivity[category] =
            (categoryProductivity[category] ?? 0) + 1;
      }

      setState(() {
        _weeklyTasks = weeklyTasks;
        _monthlyTasks = monthlyTasks;
        _categoryProductivity = categoryProductivity;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error fetching insights: $e';
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

  Widget _buildBarChart() {
    final maxTasks =
        _categoryProductivity.values.fold<int>(0, (a, b) => a > b ? a : b);
    final barGroups = _categoryProductivity.entries
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          // ignore: unused_local_variable
          final category = entry.value.key;
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
          maxY: (maxTasks + 1).toDouble(), // Add padding for visibility
          barGroups: barGroups,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  final category = _categoryProductivity.keys
                      .toList()[value.toInt()];
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
                final category =
                    _categoryProductivity.keys.toList()[group.x.toInt()];
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
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
                        'Productivity by Category',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        semanticsLabel: 'Productivity by Category',
                      ),
                      const SizedBox(height: 8),
                      _buildBarChart(),
                    ],
                  ),
                ),
    );
  }
}