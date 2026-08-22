import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import 'categories_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'results_screen.dart';

class QuizAppShell extends StatefulWidget {
  const QuizAppShell({super.key});

  @override
  State<QuizAppShell> createState() => _QuizAppShellState();
}

class _QuizAppShellState extends State<QuizAppShell> {
  final QuizController controller = QuizController();

  @override
  void initState() {
    super.initState();
    controller.addListener(_onChange);
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    controller.removeListener(_onChange);
    controller.dispose();
    super.dispose();
  }

  Widget _buildScreen() {
    switch (controller.screen) {
      case AppScreen.home:
        return HomeScreen(key: const ValueKey('home'), controller: controller);
      case AppScreen.categories:
        return CategoriesScreen(key: const ValueKey('categories'), controller: controller);
      case AppScreen.game:
        return GameScreen(key: ValueKey('game-${controller.qIndex}'), controller: controller);
      case AppScreen.results:
        return ResultsScreen(key: const ValueKey('results'), controller: controller);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.screenBackground),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ),
        child: _buildScreen(),
      ),
    );
  }
}
