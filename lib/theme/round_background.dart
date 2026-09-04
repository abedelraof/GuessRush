// One background per round, in order — cycling through them as the Rush
// progresses so each round reads as visually distinct. Split by quartile of
// the Rush's length rather than a hardcoded question count, so this keeps
// working if the server's rounds-per-Rush ever changes. Shared between
// GameScreen and FeedbackScreen so the feedback screen doesn't visually jump
// to a different background than the question it's responding to.
const List<String> kRoundBackgrounds = [
  'assets/images/app_background.png',
  'assets/images/app_background2.png',
  'assets/images/app_background3.png',
  'assets/images/app_background4.png',
];

String roundBackgroundFor(int qIndex, int questionTotal) {
  if (questionTotal <= 0) return kRoundBackgrounds.first;
  final segment = (qIndex * kRoundBackgrounds.length ~/ questionTotal).clamp(
    0,
    kRoundBackgrounds.length - 1,
  );
  return kRoundBackgrounds[segment];
}
