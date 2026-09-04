import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/auth_widgets.dart';

class SettingsScreen extends StatefulWidget {
  final QuizController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  Future<void> _pickReminderTime() async {
    final controller = widget.controller;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: controller.reminderHour, minute: controller.reminderMinute),
    );
    if (picked != null) {
      await controller.setDailyRushReminderTime(picked.hour, picked.minute);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(
              children: [
                GestureDetector(
                  onTap: controller.goHome,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('SETTINGS', style: AppFonts.baloo(size: 22)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Account',
                    child: (controller.player?.isGuest ?? true)
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Playing as Guest',
                                style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.mutedText),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Create an account to keep your progress and play with friends.',
                                style: AppFonts.inter(size: 11, weight: FontWeight.w500, color: AppColors.mutedText),
                              ),
                              const SizedBox(height: 14),
                              AuthSubmitButton(
                                label: 'Create Account',
                                loading: false,
                                onTap: controller.goToSignupFromSettings,
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.player!.displayName,
                                style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: AppColors.darkText),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                controller.player!.email,
                                style: AppFonts.inter(size: 12, weight: FontWeight.w500, color: AppColors.mutedText),
                              ),
                              const SizedBox(height: 14),
                              AuthSubmitButton(label: 'Log Out', loading: false, onTap: controller.logout),
                            ],
                          ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Audio',
                    child: Column(
                      children: [
                        _SettingsToggleRow(
                          title: 'Sound Effects',
                          subtitle: 'Countdown tick during timed questions',
                          value: controller.soundEffectsEnabled,
                          onChanged: controller.setSoundEffectsEnabled,
                        ),
                        const Divider(height: 24),
                        _SettingsToggleRow(
                          title: 'Narration',
                          subtitle: 'Spoken question narration',
                          value: controller.narrationEnabled,
                          onChanged: controller.setNarrationEnabled,
                        ),
                        const Divider(height: 24),
                        _SettingsToggleRow(
                          title: 'Haptics',
                          subtitle: 'Vibration on answers and milestones',
                          value: controller.hapticsEnabled,
                          onChanged: controller.setHapticsEnabled,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Notifications',
                    child: Column(
                      children: [
                        _SettingsToggleRow(
                          title: 'Daily Rush Reminder',
                          subtitle: 'A daily nudge to come play',
                          value: controller.dailyRushReminderEnabled,
                          onChanged: controller.setDailyRushReminderEnabled,
                        ),
                        if (controller.dailyRushReminderEnabled) ...[
                          const Divider(height: 24),
                          GestureDetector(
                            onTap: _pickReminderTime,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Reminder Time',
                                  style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.darkText),
                                ),
                                Text(
                                  TimeOfDay(
                                    hour: controller.reminderHour,
                                    minute: controller.reminderMinute,
                                  ).format(context),
                                  style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: AppColors.linkPurple),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'About',
                    child: Column(
                      children: [
                        _AboutRow(title: 'Version', trailing: _version.isEmpty ? '…' : _version),
                        const Divider(height: 24),
                        const _StubRow(title: 'Terms of Service'),
                        const Divider(height: 24),
                        const _StubRow(title: 'Privacy Policy'),
                        const Divider(height: 24),
                        const _StubRow(title: 'Contact Support'),
                        const Divider(height: 24),
                        const _StubRow(title: 'Rate the App'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppFonts.inter(size: 14, weight: FontWeight.w800, color: AppColors.darkText)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SettingsToggleRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.darkText)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppFonts.inter(size: 11, weight: FontWeight.w500, color: AppColors.mutedText)),
              ],
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.energyGold),
      ],
    );
  }
}

/// Real, static build info — not a preference, so it's just a display row.
class _AboutRow extends StatelessWidget {
  final String title;
  final String trailing;

  const _AboutRow({required this.title, required this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.darkText)),
        Text(trailing, style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: AppColors.mutedText)),
      ],
    );
  }
}

/// Visually present but inert — no Terms/Privacy copy or support email exists
/// yet to link to. Swap in a real onTap once that content is ready.
class _StubRow extends StatelessWidget {
  final String title;

  const _StubRow({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppFonts.inter(size: 14, weight: FontWeight.w700, color: AppColors.disabledText)),
        Text('Coming soon', style: AppFonts.inter(size: 11, weight: FontWeight.w600, color: AppColors.disabledText)),
      ],
    );
  }
}
