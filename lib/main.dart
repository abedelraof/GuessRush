import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/quiz_app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const QuizoApp());
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
