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
  static const _extrusionDeep = Color(0xFFD94F03);

  // The soft warm halo painted around the whole button, on top of the dark
  // purple home-screen background — see the outer outline Container's own
  // boxShadow further down.
  static const _glowA = Color(0xFFFFB000);

  // Fill color for both the "PLAY" text and the play icon.
  static const _textShadowDeep = Color(0xFF8B3500);

  // Corner radius for the button, its InkWell ripple, and its content clip —
  // kept as one named constant so all three always agree.
  static const double _cornerRadius = 24;

  // --- OUTER OUTLINE ---
  // A real black-at-70%-alpha `Container` wrapping the whole button, with
  // padding standing in for stroke width — NOT a BoxShadow trick. A
  // BoxShadow-based outline (spreadRadius + zero offset) was tried first,
  // but the 3D extrusion below only ever pushes the shape DOWN, so it ate
  // into a shadow-outline's bottom edge while leaving the top/sides alone —
  // there's no offset that makes all four sides come out equal.
  //
  // A padded container fixes the visual, but only once the extrusion's own
  // reach is a real, measured part of the layout — a BoxShadow's paint
  // overflow does NOT count toward its widget's size, so naively wrapping
  // everything in *symmetric* padding still let the extrusion bleed into
  // it. `_extrusionReach` below is reserved as actual layout space (see the
  // Padding around the surface Container further down) specifically so
  // that doesn't happen — once that space is real, this outline can just
  // use one flat `_outlineWidth` on every side and come out even.
  static const double _outlineWidth = 6;
  // How far the deepest extrusion band (_extrusionDeep, below) pushes the
  // compound shape down past the surface's own bottom edge. Both the
  // BoxShadow's own `offset` AND the Padding reserving room for it derive
  // from this one constant, so they can't drift out of sync with each
  // other again.
  static const double _extrusionReach = 5;

  // A ring of small offsets around the origin (roughly evenly spaced by
  // angle, at ~1px distance) — used below to fake a 1px outline out of
  // several nudged solid copies. See `_outlineCopies` for why a real
  // stroked outline doesn't work here.
  static const _outlineOffsets = [
    Offset(-0.7, -0.7),
    Offset(0, -1),
    Offset(0.7, -0.7),
    Offset(-1, 0),
    Offset(1, 0),
    Offset(-0.7, 0.7),
    Offset(0, 1),
    Offset(0.7, 0.7),
  ];

  // Builds the "outline" for [child] (the play icon or the "PLAY" text): a
  // ring of solid copies of it, nudged out in each of `_outlineOffsets`,
  // each recolored via the white-to-gold gradient below. The real, solid
  // `_textShadowDeep` copy then gets painted on top of these by the caller,
  // leaving only a thin gradient sliver of each copy peeking out around it.
  //
  // This is deliberately NOT a stroked outline (`Paint()..style =
  // PaintingStyle.stroke`) — Baloo2's glyph outlines are built from
  // multiple overlapping contours (normal for a display font), and
  // stroking that raw outline directly follows those contours exactly,
  // including the seams where they overlap. That left a real gap in the
  // outline at one edge of the "Y" no matter the stroke join. Every copy
  // here is an opaque glyph FILL instead, so there's no outline path to
  // develop a seam in.
  List<Widget> _outlineCopies(Widget child) {
    return [
      for (final offset in _outlineOffsets)
        Positioned(
          left: offset.dx,
          top: offset.dy,
          // ShaderMask re-colors whatever its child paints using the
          // gradient, sized to the child's real computed bounds — unlike a
          // hand-picked Rect passed straight to `createShader`, this can't
          // drift out of alignment with the actual ink (a Text's local
          // origin, for example, includes the font's built-in ascent
          // padding above the caps).
          child: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              // _surfaceTop is already #FFF94A — reused here rather than a
              // second literal for the same color.
              colors: [Colors.white, _surfaceTop],
            ).createShader(bounds),
            child: child,
          ),
        ),
    ];
  }

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
            Container(
              // Flat and symmetric now — the extrusion's reach is reserved
              // as real space by the Padding further down instead of being
              // compensated for here. See `_outlineWidth` above.
              padding: const EdgeInsets.all(_outlineWidth),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                // Concentric with the button's own `_cornerRadius` — the
                // outline's radius is that plus the padding, so the black
                // ring stays an even `_outlineWidth` thick around the
                // curve too, not just along the straight edges.
                borderRadius: BorderRadius.circular(
                  _cornerRadius + _outlineWidth,
                ),
                // --- NEON GLOW ---
                // Lives out here on the outline now (it used to be part of
                // the surface Container's own boxShadow list). Down to a
                // single soft (heavily blurred), semi-transparent shadow —
                // small spread and low opacity read as one subtle glow
                // fine on their own; the previous 3-layer buildup (tight to
                // loose) only earns its complexity when the glow is big
                // and prominent.
                boxShadow: [
                  BoxShadow(
                    color: _glowA.withValues(alpha: 0.35),
                    blurRadius: 24,
                    spreadRadius: 1,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                // Material+InkWell just for tap semantics/accessibility and the
                // standard ripple; transparent because our own Container below
                // draws all the actual visuals.
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(_cornerRadius),
                  onTap: widget.onPressed,
                  // Reserves _extrusionReach of REAL layout space below the
                  // surface Container — without this, the extrusion
                  // BoxShadow below still paints that far past the
                  // Container's bounds, but that paint overflow isn't
                  // counted in anyone's layout size, so the symmetric
                  // padding above would have no way to know to leave room
                  // for it and the extrusion would bleed into it exactly
                  // like it did with the old shadow-based outline.
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: _extrusionReach),
                    child: Container(
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
                          // Removed for now (was 3 soft blurred BoxShadows using
                          // _glowA/_glowB — those color constants are still
                          // defined above in case this comes back).
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
                            offset: Offset(0, 3),
                          ),
                          const BoxShadow(
                            color: _extrusionMid,
                            offset: Offset(0, 4),
                          ),
                          // _extrusionDeep's offset dy MUST equal _extrusionReach
                          // above — that constant feeds the outer outline
                          // Container's padding/borderRadius further down, so
                          // the outline knows exactly how far to reach past this.
                          const BoxShadow(
                            color: _extrusionDeep,
                            offset: Offset(0, _extrusionReach),
                          ),
                        ],
                      ),
                      // ClipRRect keeps everything below confined to the
                      // button's rounded shape (so nothing pokes out past the
                      // corners) — everything inside here is painted on top of
                      // the gradient/border/shadows set up above. Unlike the
                      // padding on the icon/text Row, this clip spans the
                      // button's TRUE outer bounds, which is why the gloss
                      // sheen lives in here (as a sibling of the padded content,
                      // not inside it) — otherwise it'd stop short of the
                      // padding and never reach the rounded corners.
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(_cornerRadius),
                        child: Stack(
                          children: [
                            // --- GLOSS SHEEN ---
                            // A soft, full-height white-to-transparent
                            // wash — general "lit from above" ambience.
                            // Painted on top of the surface gradient but
                            // behind the icon/text so it doesn't wash them
                            // out (`IgnorePointer` keeps it from stealing
                            // the InkWell's tap). Used to also have a
                            // distinct, brighter rounded highlight strip
                            // inset near the top, on top of this — removed.
                            Positioned.fill(
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      stops: const [0.0, 0.65],
                                      colors: [
                                        Colors.white.withValues(alpha: 0.7),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // --- BOTTOM SHADE ---
                            // A flat 20%-opacity black rectangle over exactly
                            // the bottom half — deepens the "lit from above"
                            // contrast the gloss above already creates, so the
                            // top reads even brighter/glossier by comparison.
                            // Positioned.fill (matching the other overlay
                            // layers here) keeps this out of the Stack's own
                            // sizing pass — without it, Align has no bounded
                            // height to work from and FractionallySizedBox
                            // crashes trying to take half of an infinite one.
                            //
                            // `widthFactor: 1.0` is NOT optional here — with
                            // only heightFactor set, FractionallySizedBox
                            // derives width from its child's own intrinsic
                            // width instead. A childless DecoratedBox has no
                            // intrinsic width, so the whole box was silently
                            // collapsing to zero width (invisible, regardless
                            // of the color's opacity).
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: FractionallySizedBox(
                                  heightFactor: 0.5,
                                  widthFactor: 1.0,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // The actual button content: play icon + "PLAY"
                            // label. `mainAxisSize.min` on the Row is what
                            // makes it (and therefore the button around it)
                            // hug this content instead of trying to expand.
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // --- PLAY ICON, with the same gradient
                                  // outline as the "PLAY" text below (see
                                  // `_outlineCopies`). ---
                                  SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: Stack(
                                      children: [
                                        ..._outlineCopies(
                                          const Icon(
                                            Icons.play_arrow_rounded,
                                            size: 38,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.play_arrow_rounded,
                                          size: 38,
                                          color: _textShadowDeep,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // --- "PLAY" TEXT, with a gradient outline ---
                                  // Inter (not Baloo2) — matching the font
                                  // family "PLAY WITH FRIENDS" uses below.
                                  // See `_outlineCopies` for why this is a
                                  // ring of offset solid copies rather than
                                  // a stroked outline.
                                  Stack(
                                    children: [
                                      ..._outlineCopies(
                                        Text(
                                          'PLAY',
                                          style: AppFonts.inter(
                                            size: 36,
                                            weight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'PLAY',
                                        style: AppFonts.inter(
                                          size: 36,
                                          weight: FontWeight.w800,
                                          color: _textShadowDeep,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // The highlight line lives out here, as a sibling of the
            // outline Container above — NOT inside it — so it's positioned
            // relative to the Stack's full bounds (outline included), not
            // just the surface underneath it. That's also why every value
            // below has `_outlineWidth` added on: without it, "top: 4"
            // would mean 4px below the OUTLINE's top edge (landing inside
            // the black margin) rather than 4px below the surface's own
            // top edge, where it's meant to sit.
            Positioned(
              left: 24 + _outlineWidth,
              right: 24 + _outlineWidth,
              top: 4 + _outlineWidth,
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
