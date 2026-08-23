import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import 'categories_screen.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'leaderboard_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'results_screen.dart';
import 'signup_screen.dart';

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
    controller.bootstrap();
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
      case AppScreen.boot:
        return const SizedBox.expand(
          key: ValueKey('boot'),
          child: Center(child: CircularProgressIndicator(color: Colors.white)),
        );
      case AppScreen.login:
        return LoginScreen(key: const ValueKey('login'), controller: controller);
      case AppScreen.signup:
        return SignupScreen(key: const ValueKey('signup'), controller: controller);
      case AppScreen.home:
        return HomeScreen(key: const ValueKey('home'), controller: controller);
      case AppScreen.categories:
        return CategoriesScreen(key: const ValueKey('categories'), controller: controller);
      case AppScreen.game:
        return GameScreen(key: ValueKey('game-${controller.qIndex}'), controller: controller);
      case AppScreen.results:
        return ResultsScreen(key: const ValueKey('results'), controller: controller);
      case AppScreen.profile:
        return ProfileScreen(key: const ValueKey('profile'), controller: controller);
      case AppScreen.leaderboard:
        return LeaderboardScreen(key: const ValueKey('leaderboard'), controller: controller);
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
