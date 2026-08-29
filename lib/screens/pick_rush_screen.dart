import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/game_mode.dart';
import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/pressable_scale.dart';

/// Static display metadata for one Pick Your Rush mode card. Fixed/small (4
/// entries), unlike Category — no reason for a server-driven model here.
class _RushModeInfo {
  final GameMode mode;
  final String assetPath;
  final String title;
  final String tagline;
  final String description;
  final Gradient gradient;

  const _RushModeInfo({
    required this.mode,
    required this.assetPath,
    required this.title,
    required this.tagline,
    required this.description,
    required this.gradient,
  });
}

const _kRushModes = [
  _RushModeInfo(
    mode: GameMode.quickRush,
    assetPath: 'assets/images/quick_rush.png',
    title: 'Quick Rush',
    tagline: 'Fast & unpredictable',
    description: 'A fast mixed challenge pulling from everything.',
    // Reuses the PLAY button's own gradient — same energetic identity.
    gradient: AppColors.playNowButton,
  ),
  _RushModeInfo(
    mode: GameMode.chaosRush,
    assetPath: 'assets/images/chaos_rush.png',
    title: 'Chaos Rush',
    tagline: 'Anything can happen',
    description: 'Text, emoji, image, video, audio — no pattern.',
    gradient: AppColors.questionLabel,
  ),
  _RushModeInfo(
    mode: GameMode.streakRush,
    assetPath: 'assets/images/streak_rush.png',
    title: 'Streak Rush',
    tagline: 'How far can you go?',
    description: 'Keep answering to build your streak. One miss ends it.',
    gradient: AppColors.streakBadge,
  ),
  _RushModeInfo(
    mode: GameMode.chillRush,
    assetPath: 'assets/images/chill_rush.png',
    title: 'Chill Rush',
    tagline: 'No pressure, just guess',
    description: 'No timer, no rush — play at your own pace.',
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [AppColors.tileBlue, AppColors.logoBlue],
    ),
  ),
];

/// One decorative dot scattered across a card's background — all circles on
/// a card share `_kCircleColor`; only size, position, and opacity vary.
class _CardCircle {
  final Alignment alignment;
  final double size;
  final double opacity;

  const _CardCircle(this.alignment, this.size, this.opacity);
}

const _kCircleColor = Colors.white;

/// Deterministic per-mode "randomness" — seeded by `seed` so each card's
/// scatter of circles looks hand-placed and stays put across rebuilds
/// (isPending/isDimmed toggling shouldn't make them jump around), while
/// still differing from one mode's card to the next. Placement uses simple
/// rejection sampling (retry a new spot if it lands too close to an already-
/// placed circle) so the result reads as spread out rather than clumped —
/// `minSeparation` scales down as `count` grows so it can still always place
/// every circle instead of stalling out.
List<_CardCircle> _generateCircles(int seed, int count) {
  final rng = math.Random(seed);
  final minSeparation = 1.7 / math.sqrt(count);
  final placed = <Alignment>[];

  // Biases y toward the bottom edge (+1): raising a uniform [0,1] value to a
  // fractional power pushes it up toward 1 rather than spreading it evenly —
  // the lower the exponent, the harder that push, so most circles cluster
  // near the bottom and only a few reach up toward the top.
  double biasedY() => -1 + 2 * math.pow(rng.nextDouble(), 0.4).toDouble();

  Alignment randomPoint() => Alignment(rng.nextDouble() * 2 - 1, biasedY());

  Alignment bestCandidate() {
    Alignment best = randomPoint();
    double bestMinDist = -1;
    for (var attempt = 0; attempt < 40; attempt++) {
      final candidate = randomPoint();
      final minDist = placed.isEmpty
          ? double.infinity
          : placed
              .map((p) => math.sqrt(math.pow(p.x - candidate.x, 2) + math.pow(p.y - candidate.y, 2)))
              .reduce(math.min);
      if (minDist > bestMinDist) {
        best = candidate;
        bestMinDist = minDist;
      }
      if (minDist >= minSeparation) break;
    }
    return best;
  }

  return List.generate(count, (_) {
    final alignment = bestCandidate();
    placed.add(alignment);
    final size = 12 + rng.nextDouble() * 30;
    // Fades out toward the top: a circle's own opacity is scaled by how far
    // down the card it landed (0 at the very top edge, 1 at the very bottom),
    // on top of the density bias above — so the top isn't just sparser, the
    // few circles that do land there are also noticeably dimmer.
    final verticalFade = (alignment.y + 1) / 2;
    final opacity = (0.10 + rng.nextDouble() * 0.15) * (0.25 + 0.75 * verticalFade);
    return _CardCircle(alignment, size, opacity);
  });
}

class _RushModeCard extends StatelessWidget {
  final _RushModeInfo info;
  final bool isPending;
  final bool isDimmed;
  final VoidCallback? onTap;

  const _RushModeCard({
    super.key,
    required this.info,
    required this.isPending,
    required this.isDimmed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: isDimmed ? 0.35 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: info.gradient,
            borderRadius: BorderRadius.circular(28),
            border: isPending
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 20, offset: Offset(0, 10)),
            ],
          ),
          child: Stack(
            children: [
              // Decorative background dots — varied size/color/position, behind everything else.
              for (final circle in _generateCircles(info.mode.index, 14))
                Align(
                  alignment: circle.alignment,
                  child: IgnorePointer(
                    child: Container(
                      width: circle.size,
                      height: circle.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kCircleColor.withValues(alpha: circle.opacity),
                      ),
                    ),
                  ),
                ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset(info.assetPath, height: 104),
                  const SizedBox(height: 8),
                  Text(info.title, style: AppFonts.baloo(size: 19, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    info.tagline.toUpperCase(),
                    style: AppFonts.inter(
                      size: 11,
                      weight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.85),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    info.description,
                    style: AppFonts.inter(
                      size: 12,
                      weight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
              if (isPending)
                Positioned(
                  top: 0,
                  right: 0,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.25),
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

/// "Pick Your Rush" — the game-mode selection screen shown after tapping Play,
/// replacing the old "Pick a Category" screen. The player picks a Rush mode
/// (Quick/Chaos/Streak/Chill); category stays entirely internal to the
/// server's question-selection logic and is never surfaced here.
class PickRushScreen extends StatefulWidget {
  final QuizController controller;

  const PickRushScreen({super.key, required this.controller});

  @override
  State<PickRushScreen> createState() => _PickRushScreenState();
}

class _PickRushScreenState extends State<PickRushScreen> {
  // Which card the player just tapped — drives the per-card "this one's
  // loading" highlight instead of one generic full-screen scrim, so it's
  // clear which mode was actually selected. Self-clears once
  // controller.isCreatingSession goes false again (success or error).
  GameMode? _pendingMode;

  void _handleTap(GameMode mode) {
    if (widget.controller.isCreatingSession) return;
    setState(() => _pendingMode = mode);
    widget.controller.startRush(mode);
  }

  Widget _buildCard(_RushModeInfo info) {
    final isCreating = widget.controller.isCreatingSession;
    return _RushModeCard(
      key: ValueKey('rush-mode-card-${info.mode.name}'),
      info: info,
      isPending: isCreating && _pendingMode == info.mode,
      isDimmed: isCreating && _pendingMode != info.mode,
      onTap: isCreating ? null : () => _handleTap(info.mode),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
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
                    onTap: controller.goHome,
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
                    'Pick Your Rush',
                    overflow: TextOverflow.ellipsis,
                    style: AppFonts.baloo(size: 24),
                  ),
                ),
              ],
            ),
            if (controller.errorMessage != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.errorMessage!,
                  style: AppFonts.inter(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.feedbackWrongTitle,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildCard(_kRushModes[0])),
                        const SizedBox(width: 14),
                        Expanded(child: _buildCard(_kRushModes[1])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _buildCard(_kRushModes[2])),
                        const SizedBox(width: 14),
                        Expanded(child: _buildCard(_kRushModes[3])),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
