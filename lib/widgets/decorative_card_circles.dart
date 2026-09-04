import 'dart:math' as math;

import 'package:flutter/material.dart';

class _CardCircle {
  final Alignment alignment;
  final double size;
  final double opacity;

  const _CardCircle(this.alignment, this.size, this.opacity);
}

/// Deterministic per-card "randomness" — seeded by `seed` so each card's
/// scatter of circles looks hand-placed and stays put across rebuilds, while
/// still differing from one card to the next. Placement uses simple
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
                .map(
                  (p) => math.sqrt(
                    math.pow(p.x - candidate.x, 2) +
                        math.pow(p.y - candidate.y, 2),
                  ),
                )
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
    final opacity =
        (0.10 + rng.nextDouble() * 0.15) * (0.25 + 0.75 * verticalFade);
    return _CardCircle(alignment, size, opacity);
  });
}

/// Decorative dots scattered across a card's background — drop into a
/// [Stack] behind a card's content. All circles share white; only size,
/// position, and opacity vary. `seed` should be stable per-card (e.g. an
/// enum index) so the scatter doesn't jump around on rebuild.
class DecorativeCardCircles extends StatelessWidget {
  final int seed;
  final int count;

  const DecorativeCardCircles({super.key, required this.seed, this.count = 14});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (final circle in _generateCircles(seed, count))
          Align(
            alignment: circle.alignment,
            child: IgnorePointer(
              child: Container(
                width: circle.size,
                height: circle.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: circle.opacity),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
