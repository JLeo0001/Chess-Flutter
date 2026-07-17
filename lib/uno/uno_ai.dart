import 'dart:math';
import 'uno_card.dart';
import 'uno_game.dart';

class UnoAI {
  final Random _rng = Random();

  int? chooseCard(UnoGame game, int playerIdx) {
    final playable = game.playableIndices(playerIdx);
    if (playable.isEmpty) return null;
    final hand = game.hands[playerIdx];
    if (playable.length == 1) return playable[0];

    // prefer number cards over function/wild
    final numbers = playable.where((i) => hand[i].isNumber).toList();
    if (numbers.isNotEmpty) {
      // prefer matching current color
      final matching = numbers.where((i) => hand[i].color == game.currentColor).toList();
      if (matching.isNotEmpty) return matching[_rng.nextInt(matching.length)];
      return numbers[_rng.nextInt(numbers.length)];
    }
    // function cards except wild
    final funcs = playable.where((i) => !hand[i].isWild).toList();
    if (funcs.isNotEmpty) return funcs[_rng.nextInt(funcs.length)];
    return playable[_rng.nextInt(playable.length)];
  }

  UnoColor chooseColor(UnoGame game, int playerIdx) {
    final hand = game.hands[playerIdx];
    final counts = <UnoColor, int>{};
    for (final c in hand) {
      if (c.color != null) counts[c.color!] = (counts[c.color!] ?? 0) + 1;
    }
    if (counts.isEmpty) return UnoColor.values[_rng.nextInt(4)];
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}
