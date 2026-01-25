import 'dart:math';

double _expectedScore(double myRating, double opponentRating) {
  return 1.0 / (1.0 + pow(10, (opponentRating - myRating) / 400));
}

int calculateEloDelta({
  required int myRating,
  required int opponentRating,
  required bool isWin,
  int kFactor = 32,
}) {
  final expected = _expectedScore(
    myRating.toDouble(),
    opponentRating.toDouble(),
  );

  final actual = isWin ? 1.0 : 0.0;
  final delta = kFactor * (actual - expected);

  return delta.round();
}
