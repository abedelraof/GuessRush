import 'package:flutter/material.dart';

import '../theme/text_styles.dart';

/// The GuessRush primary CTA — a rounded-rectangle "PLAY" button styled to
/// look like a chunky, glossy 3D arcade-game button.
///
/// Despite the layered look (gradient surface, border, glow, 3D extrusion,
/// highlight line, drop-shadowed icon/text), this is still just ONE
/// `Container` for the button body — no separate Positioned "layers" stacked
/// behind it. Every 3D-looking effect below is faked with plain Flutter
/// primitives (multiple `BoxShadow`s, duplicated `Text`/`Icon` widgets
/// offset slightly). See the comments at each section for how/why.
///
/// The button sizes itself to its content (icon + "PLAY" + padding) — it has
/// no `width` field, so it never needs a caller to guess a pixel size, and it
/// can't overflow narrow screens.
class GuessRushPlayButton extends StatefulWidget {
  /// Called on tap. If null, the button still shows its press animation but
  /// does nothing when released (matches `InkWell`'s own null-onTap behavior).
  final VoidCallback? onPressed;

  const GuessRushPlayButton({super.key, this.onPressed});

  @override
  State<GuessRushPlayButton> createState() => _GuessRushPlayButtonState();
}

class _GuessRushPlayButtonState extends State<GuessRushPlayButton> {
  /// True for as long as a finger/pointer is down on the button. Drives the
  /// "press into the screen" animation — see the `AnimatedContainer` below.
  bool _pressed = false;

  // ---------------------------------------------------------------------
  // COLOR PALETTE
  // All colors are named constants (rather than inlined hex values) so the
  // gradient/extrusion/glow definitions below read as "top color, middle
  // color, bottom color" instead of a wall of hex codes.
  // ---------------------------------------------------------------------

  // Main surface gradient, top -> bottom: bright lemon yellow fading down to
  // a warm orange. This is what makes the button look "lit from above".
  static const _surfaceTop = Color(0xFFFFF94A);
  static const _surfaceUpper = Color(0xFFFFF12A);
  static const _surfaceCenter = Color(0xFFFFD21A);
  static const _surfaceBottom = Color(0xFFFF9D00);

  // The cream-yellow ring drawn around the pill's outer edge.
  static const _border = Color(0xFFFFF7A8);

  // The "3D extrusion" colors, light -> dark. These paint as three stacked
  // solid-color copies of the button's own pill shape (see boxShadow below),
  // which is what gives the button its thick, molded-plastic look.
  static const _extrusionLight = Color(0xFFE87500);
  static const _extrusionMid = Color(0xFFB94E00);
  static const _extrusionDeep = Color(0xFF7C2B00);

  // The soft warm halo painted around the whole button, on top of the dark
  // purple home-screen background.
  static const _glowA = Color(0xFFFFB000);
  static const _glowB = Color(0xFFFFC400);

  // Drop-shadow colors used behind the white "PLAY" text and the white play
  // icon, to give them the same molded/dimensional look as the button itself.
  static const _textShadowDeep = Color(0xFF8B3500);
  static const _iconShadow = Color(0xFF8C3500);

  // Corner radius for the button, its InkWell ripple, and its content clip —
  // kept as one named constant so all three always agree.
  static const double _cornerRadius = 24;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Track finger-down/finger-up/cancelled ourselves (rather than relying
      // only on InkWell's onTap) so we can drive the press-in animation below.
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        // The "press" feel: nudge the whole button down 4px when held, and
        // spring back up on release. AnimatedContainer automatically
        // animates any change to its `transform` between old/new values —
        // no AnimationController needed for something this simple.
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        // An outer Stack, so the highlight line below can sit OUTSIDE the
        // bordered/clipped button body and be positioned relative to the
        // button's true outer edge (border included) instead of relative to
        // the content area inside the border.
        child: Stack(
          children: [
            Material(
              // Material+InkWell just for tap semantics/accessibility and the
              // standard ripple; transparent because our own Container below
              // draws all the actual visuals.
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(_cornerRadius),
                onTap: widget.onPressed,
                child: Container(
                  // Padding (not a fixed width/height) is what sizes this button
                  // to its content — see the class doc comment.
                  //
                  // Left/right are NOT equal on purpose: the play glyph has
                  // built-in empty space on its left within its own icon box
                  // (it's a triangle pointing right, so its ink sits toward
                  // the right side of that box), while the "Y" in "PLAY" ink
                  // runs almost all the way to the text's own right edge. An
                  // equal padding therefore LOOKS unequal — the icon reads
                  // as having a bigger gap to the button's edge than the
                  // text does. Keeping `left` 12 less than `right` is what
                  // compensates for that, so the two visible gaps end up
                  // the same width.
                  padding: const EdgeInsets.only(
                    left: 22,
                    right: 34,
                    top: 8,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    // The glossy yellow-to-orange surface color.
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      // Stops are NOT evenly spaced (0, 0.28, 0.6, 1.0) — the top
                      // two colors are bunched closer together so the "bright"
                      // part of the gradient dominates and the orange only
                      // really shows up in the bottom ~40%. That's what reads as
                      // "lit from above" instead of a plain diagonal fade.
                      stops: [0.0, 0.28, 0.6, 1.0],
                      colors: [
                        _surfaceTop,
                        _surfaceUpper,
                        _surfaceCenter,
                        _surfaceBottom,
                      ],
                    ),
                    border: Border.all(color: _border, width: 3),
                    // Every "layer" of this button (glow, 3D extrusion) is really
                    // just an entry in this single boxShadow list. Flutter paints
                    // BoxShadows in list order, each one on top of the previous —
                    // so the ordering below is deliberate: glow first (painted
                    // first = ends up furthest "back"), then the three crisp
                    // extrusion bands on top of it.
                    boxShadow: [
                      // --- NEON GLOW ---
                      // Two large, soft (heavily blurred), semi-transparent
                      // shadows. Because they're so blurred, they spread out well
                      // beyond the button's own edge and light up the dark
                      // background around it, rather than looking like a shadow
                      // "on" the button.
                      BoxShadow(
                        color: _glowA.withValues(alpha: 0.5),
                        blurRadius: 26,
                        spreadRadius: 1,
                        offset: const Offset(0, 6),
                      ),
                      BoxShadow(
                        color: _glowB.withValues(alpha: 0.45),
                        blurRadius: 20,
                        offset: const Offset(0, 2),
                      ),
                      // --- 3D EXTRUSION ---
                      // Three SOLID (blurRadius: 0), fully-opaque shadows, each a
                      // little further down than the last. A zero-blur BoxShadow
                      // is just a flat-color duplicate of the widget's own
                      // rounded-pill silhouette — so each of these paints a
                      // second identical pill, offset a few pixels down.
                      //
                      // Because later entries paint OVER earlier ones, and each
                      // is offset slightly more than the last, only a thin sliver
                      // of each shadow ends up visible: extrusionLight peeks out
                      // above extrusionMid, which peeks out above extrusionDeep.
                      // Seen together those three slivers read as one smooth
                      // light-to-dark gradient band underneath the button — a
                      // "3D extrusion" without needing a second widget/layer.
                      const BoxShadow(
                        color: _extrusionLight,
                        offset: Offset(0, 4),
                      ),
                      const BoxShadow(
                        color: _extrusionMid,
                        offset: Offset(0, 6),
                      ),
                      const BoxShadow(
                        color: _extrusionDeep,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  // ClipRRect keeps the icon/text below confined to the
                  // button's rounded shape (so nothing pokes out past the
                  // corners) — everything inside here is painted on top of
                  // the gradient/border/shadows set up above.
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_cornerRadius),
                    // The actual button content: play icon + "PLAY" label.
                    // `mainAxisSize.min` is what makes the Row (and therefore the
                    // button around it) hug this content instead of trying to
                    // expand.
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // --- PLAY ICON, with a drop shadow ---
                        // A single dark copy of the icon sits underneath
                        // (offset down by 3px), and the real white icon is
                        // drawn on top of it — the classic "duplicate the
                        // shape, offset it, put the real one on top" trick
                        // for a hard-edged drop shadow (as opposed to
                        // BoxShadow's blurred kind).
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Positioned(
                                top: 3,
                                child: Icon(
                                  Icons.play_arrow_rounded,
                                  size: 38,
                                  color: _iconShadow,
                                ),
                              ),
                              const Icon(
                                Icons.play_arrow_rounded,
                                size: 38,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // --- "PLAY" TEXT, with a drop shadow + gradient outline ---
                        // Three copies of the same text, stacked bottom to
                        // top:
                        //   1. a white copy offset down 5px = the shadow.
                        //   2. a STROKE-only copy, same position as the
                        //      real text, painted with a gradient Paint
                        //      instead of a flat color = the outline. Only
                        //      its outer edge is visible once the solid
                        //      fill copy is painted on top of it.
                        //   3. the real, solid `_textShadowDeep` fill text.
                        Stack(
                          children: [
                            Positioned(
                              left: 0,
                              top: 5,
                              child: Text(
                                'PLAY',
                                style: AppFonts.baloo(
                                  size: 36,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            Text(
                              'PLAY',
                              style: AppFonts.baloo(
                                size: 36,
                                foreground: Paint()
                                  ..style = PaintingStyle.stroke
                                  ..strokeWidth = 3
                                  ..shader =
                                      const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [_surfaceTop, _surfaceBottom],
                                      ).createShader(
                                        const Rect.fromLTWH(0, -6, 140, 50),
                                      ),
                              ),
                            ),
                            Text(
                              'PLAY',
                              style: AppFonts.baloo(
                                size: 36,
                                color: _textShadowDeep,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The highlight line lives out here, as a sibling of the
            // Material/InkWell/Container above — NOT inside the border/clip —
            // so `top` is measured from the button's true outer edge, not
            // from just inside the border. `top: 4` leaves a small visible
            // gap below the outer edge before the line starts.
            Positioned(
              left: 24,
              right: 24,
              top: 4,
              height: 2,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
