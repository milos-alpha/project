import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class ScheduleTab extends StatefulWidget {
  const ScheduleTab({Key? key}) : super(key: key);

  @override
  State<ScheduleTab> createState() => _ScheduleTabState();
}

class _ScheduleTabState extends State<ScheduleTab> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> weeklySchedule = [];
  List<Map<String, dynamic>> dailySchedule = [];

  // Constants
  static const String weeklyScheduleKey = 'weeklySchedule';
  static const String dailyScheduleKey = 'dailySchedule';
  static const String scheduleChannelId = 'schedule_channel';
  static const String scheduleChannelName = 'Schedule Notifications';
  static const String dailyScheduleReminderTitle = 'Daily Schedule Reminder';
  static const String coveredAction = 'covered';
  static const String notCoveredAction = 'not_covered';
  static const String coveredText = 'Covered';
  static const String notCoveredText = 'Not Covered';
  static const String descriptionLabel = 'Description';
  static const String timeLabel = 'Time (HH:mm)';
  static const String addWeeklyScheduleTitle = 'Add Weekly Schedule';
  static const String addDailyScheduleTitle = 'Add Daily Schedule';
  static const String selectDateText = 'Select date';
  static const String dateFormat = 'yyyy-MM-dd';
  static const String timeFormat = 'HH:mm';
  static const String editSchedulesTitle = 'Edit Schedules';
  static const String weeklyScheduleText = 'Weekly Schedule:';
  static const String dailyScheduleText = 'Daily Schedule:';
  static const String weeklyTasksText = 'Weekly Tasks';
  static const String invalidTimeFormat = 'Invalid time format';
  static const String pleaseFillAllFields = 'Please fill all fields';
  static const String saveText = 'Save';
  static const String cancelText = 'Cancel';
  static const String closeText = 'Close';
  static const String monday = 'Monday';
  static const String tuesday = 'Tuesday';
  static const String wednesday = 'Wednesday';
  static const String thursday = 'Thursday';
  static const String friday = 'Friday';
  static const String saturday = 'Saturday';
  static const String sunday = 'Sunday';

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

        if (response.actionId == coveredAction) {
          setState(() {
            List<Map<String, dynamic>> scheduleToUpdate =
            isWeekly ? weeklySchedule : dailySchedule;
            if (index >= 0 && index < scheduleToUpdate.length) {
              scheduleToUpdate[index]['covered'] = true;
            } else {
              debugPrint(
                  'Invalid index: $index for ${isWeekly ? "weekly" : "daily"} schedule');
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
            json.decode(prefs.getString(weeklyScheduleKey) ?? '[]'));
        dailySchedule = List<Map<String, dynamic>>.from(
            json.decode(prefs.getString(dailyScheduleKey) ?? '[]'));
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
    }
  }

  Future<void> _saveSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setString(weeklyScheduleKey, json.encode(weeklySchedule));
      await prefs.setString(dailyScheduleKey, json.encode(dailySchedule));
    } catch (e) {
      debugPrint('Error saving schedules: $e');
    }
  }

  Future<void> _scheduleNotification(String title, String body,
      DateTime scheduledTime, bool isWeekly, int index) async {
    const androidDetails = AndroidNotificationDetails(
      scheduleChannelId,
      scheduleChannelName,
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction(coveredAction, coveredText),
        AndroidNotificationAction(notCoveredAction, notCoveredText),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: 'schedule',
    );
    const details =
    NotificationDetails(android: androidDetails, iOS: iosDetails);

    try {
      final tz.TZDateTime tzScheduledTime =
      tz.TZDateTime.from(scheduledTime, tz.local);

      await flutterLocalNotificationsPlugin.zonedSchedule(
        index + (isWeekly ? 1000 : 0),
        title,
        body,
        tzScheduledTime,
        details,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
      );
    } catch (e) {
      debugPrint('Error scheduling notification: $e');
    }
  }

  Future<void> _showScheduleModal(bool isWeekly) async {
    if (isWeekly) {
      return _showWeeklyScheduleModal();
    } else {
      return _showDailyScheduleModal();
    }
  }

  Future<void> _showWeeklyScheduleModal() async {
    List<TextEditingController> descriptionControllers =
    List.generate(7, (_) => TextEditingController());
    List<String> dayNames = [
      monday,
      tuesday,
      wednesday,
      thursday,
      friday,
      saturday,
      sunday,
    ];

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(addWeeklyScheduleTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              7,
                  (index) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Text('${dayNames[index]}: '),
                    Expanded(
                      child: TextField(
                        controller: descriptionControllers[index],
                        decoration: const InputDecoration(
                          labelText: descriptionLabel,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(cancelText),
          ),
          TextButton(
            onPressed: () async {
              Map<String, String> weeklyTasks = {};
              for (int i = 0; i < 7; i++) {
                weeklyTasks[dayNames[i]] = descriptionControllers[i].text;
              }

              setState(() {
                weeklySchedule.add({
                  'tasks': weeklyTasks,
                });
              });

              await _saveSchedules();
              Navigator.pop(context);
            },
            child: const Text(saveText),
          ),
        ],
      ),
    );
  }

  Future<void> _showDailyScheduleModal() async {
    final timeController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    Future<void> _selectDate(BuildContext context) async {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: selectedDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2026),
      );
      if (picked != null && picked != selectedDate) {
        setState(() {
          selectedDate = picked;
        });
      }
    }

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(addDailyScheduleTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(
                    "Date: ${DateFormat(dateFormat).format(selectedDate)}"),
                TextButton(
                  onPressed: () => _selectDate(context),
                  child: const Text(selectDateText),
                ),
              ],
            ),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: timeLabel,
              ),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(
                labelText: descriptionLabel,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(cancelText),
          ),
          TextButton(
            onPressed: () async {
              if (timeController.text.isEmpty ||
                  descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(pleaseFillAllFields)),
                );
                return;
              }
              try {
                final parsedTime =
                DateFormat(timeFormat).parse(timeController.text);
                final scheduledTime = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  parsedTime.hour,
                  parsedTime.minute,
                );

                final schedule = {
                  'date': DateFormat(dateFormat).format(selectedDate),
                  'time': timeController.text,
                  'description': descriptionController.text,
                  'covered': false,
                };

                setState(() {
                  dailySchedule.add(schedule);
                });

                await _scheduleNotification(
                  dailyScheduleReminderTitle,
                  descriptionController.text,
                  scheduledTime,
                  false,
                  dailySchedule.length - 1,
                );
                await _saveSchedules();
                Navigator.pop(context);
              } catch (e) {
                debugPrint('Error parsing time: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text(invalidTimeFormat)),
                );
              }
            },
            child: const Text(saveText),
          ),
        ],
      ),
    );
  }

  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(editSchedulesTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(weeklyScheduleText,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...weeklySchedule.asMap().entries.map((entry) {
                Map<String, String> tasks =
                Map<String, String>.from(entry.value['tasks']);
                return ExpansionTile(
                  title: const Text(weeklyTasksText),
                  children: tasks.entries
                      .map((taskEntry) => ListTile(
                    title: Text('${taskEntry.key}: ${taskEntry.value}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () async {
                        setState(() {
                          weeklySchedule.removeAt(entry.key);
                        });
                        await _saveSchedules();
                      },
                    ),
                  ))
                      .toList(),
                );
              }),
              const SizedBox(height: 16),
              const Text(dailyScheduleText,
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ...dailySchedule.asMap().entries.map((entry) => ListTile(
                title: Text(
                    '${entry.value['date']} - ${entry.value['description'] as String}'),
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
            child: const Text(closeText),
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
              child: const Text(addWeeklyScheduleTitle),
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton(
              onPressed: () => _showScheduleModal(false),
              child: const Text(addDailyScheduleTitle),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _showEditDialog,
              child: const Text(editSchedulesTitle),
            ),
          ),
        ],
      ),
    );
  }
}
