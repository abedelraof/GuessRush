import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';

/// Shown while waiting for a 1v1 match to start — either searching the
/// random queue, or the friend-invite sub-flow (create a code and share it,
/// or enter one a friend sent). Gameplay itself starts automatically the
/// moment QuizController's match:paired handling fires (see _beginMatch).
class MatchWaitingScreen extends StatefulWidget {
  final QuizController controller;

  const MatchWaitingScreen({super.key, required this.controller});

  @override
  State<MatchWaitingScreen> createState() => _MatchWaitingScreenState();
}

class _MatchWaitingScreenState extends State<MatchWaitingScreen> {
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty || _joining) return;
    setState(() => _joining = true);
    await widget.controller.joinFriendMatch(code);
    if (mounted) setState(() => _joining = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final isRandom = controller.matchFlowKind == MatchFlowKind.random;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: isRandom ? () => controller.cancelQueue() : controller.backFromPlayWithFriends,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text('←', style: AppFonts.inter(size: 16, weight: FontWeight.w800)),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    isRandom ? 'Finding an Opponent' : 'Play with a Friend',
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.baloo(size: 22),
                  ),
                ),
              ],
            ),
            if (controller.matchError != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.matchError!,
                  style: AppFonts.inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.feedbackWrongTitle,
                  ),
                ),
              ),
            ],
            Expanded(
              child: Center(child: isRandom ? _buildSearching() : _buildFriend(controller)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearching() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
        const SizedBox(height: 20),
        Text('Searching for an opponent…', style: AppFonts.inter(size: 15, weight: FontWeight.w700)),
      ],
    );
  }

  Widget _buildFriend(QuizController controller) {
    return controller.friendInviteCode != null ? _buildHosting(controller) : _buildChoose(controller);
  }

  Widget _buildChoose(QuizController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Have a code?', style: AppFonts.baloo(size: 16)),
              const SizedBox(height: 10),
              TextField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: AppFonts.baloo(size: 22, color: AppColors.darkText, letterSpacing: 4),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'ABC123',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 10),
              _PrimaryButton(label: _joining ? 'Joining…' : 'Join', onTap: _joining ? null : _submitCode),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'or',
          textAlign: TextAlign.center,
          style: AppFonts.inter(size: 13, weight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(label: 'Create an Invite', onTap: () => controller.createFriendInvite()),
      ],
    );
  }

  Widget _buildHosting(QuizController controller) {
    final code = controller.friendInviteCode!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Share this code with your friend', style: AppFonts.inter(size: 14, weight: FontWeight.w700)),
        const SizedBox(height: 16),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copied')));
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(code, style: AppFonts.baloo(size: 34, color: AppColors.darkText, letterSpacing: 6)),
                  const SizedBox(width: 12),
                  const Icon(Icons.copy_rounded, color: AppColors.darkText, size: 22),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
        ),
        const SizedBox(height: 12),
        Text(
          'Waiting for your friend to join…',
          style: AppFonts.inter(size: 13, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: onTap == null ? Colors.white.withValues(alpha: 0.3) : AppColors.goldTimer,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(label, style: AppFonts.baloo(size: 16, color: AppColors.darkText)),
        ),
      ),
    );
  }
}
