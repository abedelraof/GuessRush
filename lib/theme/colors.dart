import 'package:flutter/material.dart';

/// All colors below are converted 1:1 from the source design's `oklch()`
/// values (OKLab -> linear sRGB -> gamma-corrected sRGB), not eyeballed.
class AppColors {
  AppColors._();

  static const Color linkPurple = Color(0xFF764BE5);

  static const Color cardWhite = Color(0xFFFAFCFE);
  static const Color darkText = Color(0xFF0E1A2F);
  static const Color mutedText = Color(0xFF3E4858);

  // Home streak badge gradient.
  static const Color streakGradA = Color(0xFFFF7300);
  static const Color streakGradB = Color(0xFFFF2F64);

  // "PLAY NOW" button gradient + shadow.
  static const Color playNowGradA = Color(0xFFEDC000);
  static const Color playNowGradB = Color(0xFFFF7500);
  static const Color playNowShadow = Color(0xFFDA4800);

  // Main screen background diagonal gradient.
  static const Color screenBgA = Color(0xFF00DFFA);
  static const Color screenBgB = Color(0xFF7D6EFF);
  static const Color screenBgC = Color(0xFFE73DCD);

  // Question label pill gradient.
  static const Color qLabelGradA = Color(0xFFF25DEA);
  static const Color qLabelGradB = Color(0xFF7D71FF);

  // Timer ring.
  static const Color goldTimer = Color(0xFFF7A224);
  static const Color timerUrgent = Color(0xFFFF464C);
  static const Color timerDefault = Color(0xFFEFCC36);

  // Image placeholder stripes.
  static const Color imgPlaceholderA = Color(0xFFC480D4);
  static const Color imgPlaceholderB = Color(0xFFAD70D7);

  // Audio waveform bars.
  static const Color wavePurple = Color(0xFF764BE5);
  static const Color wavePink = Color(0xFFDF539F);
  static const Color audioPlayGradA = Color(0xFFD852F5);
  static const Color audioPlayGradB = Color(0xFF7B53FF);

  // Video placeholder gradient.
  static const Color videoGradA = Color(0xFF1F2E47);
  static const Color videoGradB = Color(0xFF0F1528);

  // Progressive-clue reveal button.
  static const Color revealBg = Color(0xFFF0E4FF);
  static const Color revealText = Color(0xFF6A30DE);

  // Answer option states.
  static const Color correctBg = Color(0xFFB5F0B5);
  static const Color correctBorder = Color(0xFF31983D);
  static const Color wrongBg = Color(0xFFFFCFD3);
  static const Color wrongBorder = Color(0xFFE4405E);
  static const Color disabledBg = Color(0xFFF4F5F7);
  static const Color disabledText = Color(0xFF79818D);

  // Results screen.
  static const Color finalScoreGold = Color(0xFFFFBC5E);
  static const Color correctStat = Color(0xFF31983D);
  static const Color wrongStat = Color(0xFFDD3858);
  static const Color bestStreakStat = Color(0xFFDF539F);
  static const Color statLabel = Color(0xFF5D646F);
  static const Color playAgainShadow = Color(0xFFC26F00);

  // Feedback overlay.
  static const Color feedbackCorrectTitle = Color(0xFF1C882D);
  static const Color feedbackWrongTitle = Color(0xFFCB234A);
  static const Color feedbackTimeoutTitle = Color(0xFFB25B00);
  static const Color xpGoldText = Color(0xFF974E00);
  static const Color chipBg = Color(0xFFF0F2F5);
  static const Color chipText = Color(0xFF3E4858);
  static const Color streakLostText = Color(0xFF8C93A0);

  // Category tiles.
  static const Color catMovies = Color(0xFFA24AFF);
  static const Color catMusic = Color(0xFFFB2B9A);
  static const Color catCharacters = Color(0xFFFF6800);
  static const Color catGeneral = Color(0xFF009DF1);
  static const Color catSounds = Color(0xFFD6B700);
  static const Color catTv = Color(0xFF376EFF);
  static const Color catGames = Color(0xFFFF2F64);
  static const Color catTrivia = Color(0xFF00ADB1);

  // Answer-option accent hues (cycled A/B/C/D).
  static const List<Color> optionHues = [
    Color(0xFFF44DAB),
    Color(0xFF00B0FF),
    Color(0xFFDFA400),
    Color(0xFFAC61FF),
  ];

  static const LinearGradient screenBackground = LinearGradient(
    begin: Alignment(-0.5, -1),
    end: Alignment(0.5, 1),
    colors: [screenBgA, screenBgB, screenBgC],
    stops: [0, 0.5, 1],
  );

  static const LinearGradient streakBadge = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [streakGradA, streakGradB],
  );

  static const LinearGradient playNowButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [playNowGradA, playNowGradB],
  );

  static const LinearGradient questionLabel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [qLabelGradA, qLabelGradB],
  );

  static const LinearGradient audioPlayButton = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [audioPlayGradA, audioPlayGradB],
  );

  static const LinearGradient videoPlaceholder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [videoGradA, videoGradB],
  );

  static const LinearGradient imagePlaceholder = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [imgPlaceholderA, imgPlaceholderB],
  );
}
