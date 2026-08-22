import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/text_styles.dart';
import '../widgets/auth_widgets.dart';

class LoginScreen extends StatefulWidget {
  final QuizController controller;

  const LoginScreen({super.key, required this.controller});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('GUESS IT!', textAlign: TextAlign.center, style: AppFonts.baloo(size: 40)),
              const SizedBox(height: 6),
              Text(
                'Log in to play',
                textAlign: TextAlign.center,
                style: AppFonts.inter(size: 15, weight: FontWeight.w600, color: Colors.white70),
              ),
              const SizedBox(height: 28),
              if (controller.authError != null) ...[
                AuthErrorBanner(message: controller.authError!),
                const SizedBox(height: 12),
              ],
              AuthField(controller: _emailController, hint: 'Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              AuthField(controller: _passwordController, hint: 'Password', obscure: true),
              const SizedBox(height: 20),
              AuthSubmitButton(
                label: 'LOG IN',
                loading: controller.authLoading,
                onTap: () => controller.login(_emailController.text.trim(), _passwordController.text),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: controller.goToSignup,
                  child: Text(
                    "Don't have an account? Sign up",
                    style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
