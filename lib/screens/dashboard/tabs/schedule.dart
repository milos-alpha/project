import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({super.key});

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> weeklySchedule = [];
  List<Map<String, dynamic>> dailySchedule = [];

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadSchedules();
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones(); // Initialize timezone data
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );
  }

  void _handleNotificationResponse(NotificationResponse response) async {
    if (response.payload != null) {
      try {
        final data = json.decode(response.payload!);
        final isWeekly = data['isWeekly'] as bool;
        final index = data['index'] as int;

        if (response.actionId == 'covered') {
          setState(() {
            List<Map<String, dynamic>> scheduleToUpdate =
            isWeekly ? weeklySchedule : dailySchedule;
            if (index >= 0 && index < scheduleToUpdate.length) {
              scheduleToUpdate[index]['covered'] = true;
            } else {
              debugPrint('Invalid index: $index for ${isWeekly ? "weekly" : "daily"} schedule');
            }
          });
          await _saveSchedules();
        }
      } catch (e) {
        debugPrint('Error handling notification response: $e');
      }
    }
  }

  Future<void> _loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      setState(() {
        weeklySchedule = List<Map<String, dynamic>>.from(
            json.decode(prefs.getString('weeklySchedule') ?? '[]'));
        dailySchedule = List<Map<String, dynamic>>.from(
            json.decode(prefs.getString('dailySchedule') ?? '[]'));
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString('weeklySchedule', json.encode(weeklySchedule));
      await prefs.setString('dailySchedule', json.encode(dailySchedule));
    } catch (e) {
      debugPrint('Error saving schedules: $e');
    }
  }

  Future<void> _scheduleNotification(String title, String body,
      DateTime scheduledTime, bool isWeekly, int index) async {

    const androidDetails = AndroidNotificationDetails(
      'schedule_channel',
      'Schedule Notifications',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('covered', 'Covered'),
        AndroidNotificationAction('not_covered', 'Not Covered'),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'schedule',
    );
    const details =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      final tz.TZDateTime tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        index + (isWeekly ? 1000 : 0),
        title,
        body,
        tzScheduledTime,
        details,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime, androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> _showScheduleModal(bool isWeekly) async {
    final timeController = TextEditingController();
    final descriptionController = TextEditingController();

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add ${isWeekly ? "Weekly" : "Daily"} Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'Time (HH:mm)',
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (timeController.text.isEmpty ||
                  descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                final now = DateTime.now();
                final parsedTime = DateFormat('HH:mm').parse(timeController.text);
                final scheduledTime = DateTime(
                  now.year,
                  now.month,
                  now.day,
                  parsedTime.hour,
                  parsedTime.minute,
                );

                final schedule = {
                  'time': timeController.text,
                  'description': descriptionController.text,
                  'covered': false,
                };

                setState(() {
                  if (isWeekly) {
                    weeklySchedule.add(schedule);
                  } else {
                    dailySchedule.add(schedule);
                  }
                });

                await _scheduleNotification(
                  '${isWeekly ? "Weekly" : "Daily"} Schedule Reminder',
                  descriptionController.text,
                  scheduledTime,
                  isWeekly,
                  (isWeekly ? weeklySchedule : dailySchedule).length - 1,
                );
                await _saveSchedules();
                Navigator.pop(context);
              } catch (e) {
                debugPrint('Error parsing time: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid time format')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Schedules'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Weekly Schedule:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...weeklySchedule.asMap().entries.map((entry) => ListTile(
                title: Text(entry.value['description'] as String),
                subtitle: Text('Time: ${entry.value['time'] as String}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    setState(() {
                      weeklySchedule.removeAt(entry.key);
                    });
                    await _saveSchedules();
                  },
                ),
              )),
              const SizedBox(height: 16),
              const Text('Daily Schedule:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...dailySchedule.asMap().entries.map((entry) => ListTile(
                title: Text(entry.value['description'] as String),
                subtitle: Text('Time: ${entry.value['time'] as String}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    setState(() {
                      dailySchedule.removeAt(entry.key);
                    });
                    await _saveSchedules();
                  },
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => _showScheduleModal(true),
              child: const Text('Weekly Schedule'),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => _showScheduleModal(false),
              child: const Text('Daily Schedule'),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showEditDialog,
              child: const Text('Edit Schedules'),
            ),
          ),
        ],
      ),
    );
  }
}
