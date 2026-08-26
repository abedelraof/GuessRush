import 'package:flutter/material.dart';

import '../state/quiz_controller.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../widgets/guess_rush_play_button.dart';

class HomeScreen extends StatelessWidget {
  final QuizController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final name = controller.player?.displayName ?? 'Player';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'P';
    final level = controller.profile?.level;
    final trophyScore = controller.profile?.records.bestRushScore ?? 0;

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/background.png'),
          fit: BoxFit.cover,
        ),
      ),
      child: SafeArea(
        // Three rows: header and footer are each sized to their own
        // content (fixed); the middle row is wrapped in Expanded so it
        // gets whatever space is left over.
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: Column(
                  children: [
                    // --- ROW 1: header — fixed height (its own content). ---
                    _TopBar(
                      controller: controller,
                      name: name,
                      initial: initial,
                      level: level,
                      trophyScore: trophyScore,
                    ),
                    // --- ROW 2: logo + buttons — gets the rest of the
                    // space (Expanded, above). It has two rows of its own:
                    // the logo (Expanded — gets whatever room is left
                    // after the buttons below take theirs) and the
                    // buttons (sized to their own content, not flexible).
                    // A plain Column needs a bounded height to do this —
                    // that's what ruled out the old SingleChildScrollView
                    // here; a scrollable child is handed unbounded height,
                    // which is incompatible with an Expanded child asking
                    // for "whatever's left".
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: _Logo()),
                          const _Tagline(),
                          const SizedBox(height: 22),
                          GuessRushPlayButton(onPressed: controller.playNow),
                          const SizedBox(height: 14),
                          const _PlayWithFriendsButton(),
                          const SizedBox(height: 14),
                          _IconGrid(
                            onTapLeaderboard: controller.goToLeaderboard,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // --- ROW 3: footer — fixed height (its own content). ---
            _BottomNav(
              onTapEvents: controller.goToEvents,
              onTapStats: controller.goToProfile,
            ),
          ],
        ),
      ),
    );
  }
}

/// Avatar (initials — the app has no avatar-image system), name, level ring,
/// and a personal-best "trophy" pill on the left; Energy/Coins on the right.
/// Energy and Coins are intentionally NOT wired to any real system — there's
/// no play-limiting resource or currency economy in GuessRush today, and
/// building one is a real product decision, not a reskin detail (see Phase 6's
/// "avoid a currency economy unless there's a real product need"). These are
/// static display chrome matching the requested look; wire them up for real
/// if/when that decision is made.
class _TopBar extends StatelessWidget {
  final QuizController controller;
  final String name;
  final String initial;
  final int? level;
  final int trophyScore;

  const _TopBar({
    required this.controller,
    required this.name,
    required this.initial,
    required this.level,
    required this.trophyScore,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: controller.goToProfile,
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.homeMidPurple,
                        border: Border.all(
                          color: AppColors.energyGold,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.energyGold.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: AppFonts.baloo(size: 18, color: Colors.white),
                      ),
                    ),
                    if (level != null)
                      Positioned(
                        bottom: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.homeDeepNavy,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.energyGold,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$level',
                            style: AppFonts.inter(
                              size: 9,
                              weight: FontWeight.w800,
                              color: AppColors.energyGold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 10),
                // Expanded (not Flexible) so this column is GIVEN, not just allowed, exactly
                // the space left after the avatar and the fixed-width pills/button on the
                // right — the trophy pill's own Row below then has a real bound to shrink
                // against instead of silently overflowing on a narrower device/longer name.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: AppFonts.inter(
                          size: 14,
                          weight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.energyGold.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🏆', style: TextStyle(fontSize: 10)),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '$trophyScore',
                                overflow: TextOverflow.ellipsis,
                                style: AppFonts.inter(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: AppColors.energyGold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        const _ResourcePill(icon: '⚡', value: '5/5', color: AppColors.tileBlue),
        const SizedBox(width: 8),
        const _ResourcePill(
          icon: '🪙',
          value: '1,250',
          color: AppColors.coinGold,
        ),
      ],
    );
  }
}

class _ResourcePill extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;

  const _ResourcePill({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(value, style: AppFonts.inter(size: 11, weight: FontWeight.w800)),
          const SizedBox(width: 5),
          Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
              color: AppColors.addButtonGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add, size: 11, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

/// The real logo artwork (glowing "?" mark + "GUESS RUSH" wordmark), supplied
/// as a single image rather than redrawn in Flutter.
///
/// This is always used inside an `Expanded` (see HomeScreen's "ROW 2"), so
/// it's handed a real, bounded height by its parent — `fit: BoxFit.contain`
/// then does the work of fitting the artwork into whatever box that is,
/// growing or shrinking with the available space instead of a fixed size.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    // OverflowBox lets the image paint wider than the screen's own 20px
    // side padding (set on an ancestor Column further up) — its own
    // reported width still matches the padded content area, so the
    // ancestor Column doesn't see an overflow; the extra width bleeds out
    // evenly on both sides, reaching the screen's true left/right edges.
    return OverflowBox(
      maxWidth: screenWidth,
      child: Image.asset(
        'assets/images/logo.png',
        width: screenWidth,
        // `Image`'s OWN `alignment` — not `OverflowBox`'s — is what
        // matters here. `Expanded` hands OverflowBox a *tight* height, and
        // since nothing here overrides min/maxHeight, that tightness
        // propagates straight down to Image: it ends up exactly as tall
        // as the Expanded box, not just its natural aspect-ratio height.
        // `BoxFit.contain` then letterboxes the (much shorter) artwork
        // inside that tall box, and `alignment` controls where within it —
        // `bottomCenter` pushes all the slack above the artwork instead of
        // centering it, so the tagline right below sits flush against it.
        alignment: Alignment.bottomCenter,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _Tagline extends StatelessWidget {
  const _Tagline();

  @override
  Widget build(BuildContext context) {
    TextStyle base(Color color) =>
        AppFonts.inter(size: 14, weight: FontWeight.w700, color: color);
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: base(Colors.white.withValues(alpha: 0.85)),
        children: [
          const TextSpan(text: 'GUESS '),
          TextSpan(text: 'FAST', style: base(AppColors.tileBlue)),
          const TextSpan(text: '. SCORE '),
          TextSpan(text: 'BIG', style: base(AppColors.energyGold)),
          const TextSpan(text: '. BE THE '),
          TextSpan(text: 'RUSH', style: base(AppColors.tilePurple)),
          const TextSpan(text: '!'),
        ],
      ),
    );
  }
}

/// No multiplayer/friends system exists yet — inert, same precedent as the
/// other not-yet-built tiles below (Categories/How to Play previously,
/// Rewards/Shop now). Styled to match those `_IconTile`s below it (tinted
/// background/border/glow in one accent color, same 16-radius corners)
/// instead of the plain frosted-glass look it had before, so it reads as
/// part of the same button family rather than a one-off.
class _PlayWithFriendsButton extends StatelessWidget {
  const _PlayWithFriendsButton();

  @override
  Widget build(BuildContext context) {
    const color = AppColors.tilePink;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            // Higher than the icon tiles' 0.16 — this sits over a lighter
            // patch of the background art, and the low-alpha tint read as
            // washed out/hard to read there.
            color: color.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12),
            ],
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // White (not `color`) — now that the background fill is
              // much more opaque/saturated, an icon in the same accent
              // hue nearly disappeared into it.
              Icon(
                Icons.people_alt_rounded,
                size: 18,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 8),
              Text(
                'PLAY WITH FRIENDS',
                style: AppFonts.inter(
                  size: 13,
                  weight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconGrid extends StatelessWidget {
  final VoidCallback onTapLeaderboard;

  const _IconGrid({required this.onTapLeaderboard});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _IconTile(
            icon: Icons.emoji_events_rounded,
            label: 'LEADERBOARD',
            color: AppColors.tileBlue,
            onTap: onTapLeaderboard,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _IconTile(
            icon: Icons.track_changes_rounded,
            label: 'DAILY QUEST',
            color: AppColors.tilePurple,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _IconTile(
            icon: Icons.card_giftcard_rounded,
            label: 'REWARDS',
            color: AppColors.tileGreen,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: _IconTile(
            icon: Icons.shopping_cart_rounded,
            label: 'SHOP',
            color: AppColors.tileOrange,
          ),
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _IconTile({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: color.withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35),
                      blurRadius: 12,
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 26),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: AppFonts.inter(
                size: 9,
                weight: FontWeight.w800,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final VoidCallback onTapEvents;
  final VoidCallback onTapStats;

  const _BottomNav({required this.onTapEvents, required this.onTapStats});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: AppColors.homeDeepNavy.withValues(alpha: 0.9),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          // `stretch` (not the default `center`) is what makes each
          // _NavItem's Material/InkWell fill the row's full height —
          // without it, the ink splash/highlight only covered the tight
          // icon+label content, leaving a visible strip of the bar's own
          // background unhighlighted above/below it on press.
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _NavItem(
                icon: Icons.home_rounded,
                label: 'HOME',
                active: true,
              ),
              _NavItem(
                icon: Icons.star_border_rounded,
                label: 'EVENTS',
                onTap: onTapEvents,
              ),
              _NavItem(
                icon: Icons.bar_chart_rounded,
                label: 'STATS',
                onTap: onTapStats,
              ),
              const _NavItem(icon: Icons.settings_rounded, label: 'SETTINGS'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? AppColors.energyGold
        : Colors.white.withValues(alpha: 0.55);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: AppFonts.inter(
                  size: 9,
                  weight: FontWeight.w800,
                  color: color,
                ),
              ),
              if (active) ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
