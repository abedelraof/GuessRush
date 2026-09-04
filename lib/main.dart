import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'screens/quiz_app_shell.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await _initNotifications();
  runApp(const QuizoApp());
}

/// Sets up the local-notifications plugin and the device's real timezone
/// (package:timezone defaults to UTC otherwise, which would silently fire
/// the Daily Rush reminder at the wrong local time). No permission is
/// requested here — that happens only when the player turns the reminder
/// toggle on in Settings, via NotificationService.requestPermission().
Future<void> _initNotifications() async {
  tz.initializeTimeZones();
  try {
    final localZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(localZone.identifier));
  } catch (_) {
    // Falls back to UTC — the reminder will still fire, just not
    // necessarily at the exact local time the player picked.
  }

  await NotificationService.instance.plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    ),
  );
}

class QuizoApp extends StatelessWidget {
  const QuizoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Quizo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: Colors.transparent),
      home: const Scaffold(
        body: QuizAppShell(),
      ),
    );
  }
}
