import 'dart:math';
import 'uno_card.dart';

class UnoGame {
  final int playerCount;
  final Random _rng = Random();

  late List<List<UnoCard>> hands;
  late List<UnoCard> drawPile;
  late List<UnoCard> discardPile;
  int currentPlayer = 0;
  int direction = 1;
  UnoColor? wildColor;
  bool gameOver = false;
  int? winner;
  int turnCount = 0;

  UnoGame({required this.playerCount, int? startingPlayer}) {
    _init(startingPlayer ?? 0);
  }

  void _init(int firstPlayer) {
    drawPile = shuffledDeck();
    discardPile = [];
    hands = List.generate(playerCount, (_) => <UnoCard>[]);
    wildColor = null;
    currentPlayer = firstPlayer;
    direction = 1;
    gameOver = false;
    winner = null;
    turnCount = 0;

    for (int i = 0; i < 7; i++) {
      for (int p = 0; p < playerCount; p++) {
        hands[p].add(drawPile.removeAt(0));
      }
    }

    // first card must be a number card
    while (true) {
      final top = drawPile.removeAt(0);
      discardPile.add(top);
      if (top.isNumber) break;
      drawPile.insert(_rng.nextInt(drawPile.length), top);
      discardPile.removeLast();
    }
  }

  UnoCard get topCard => discardPile.last;
  UnoColor get currentColor => wildColor ?? topCard.color!;
  bool get isPlayerTurn => currentPlayer == 0;

  List<int> playableIndices(int playerIdx) {
    final hand = hands[playerIdx];
    final indices = <int>[];
    for (int i = 0; i < hand.length; i++) {
      if (hand[i].canPlayOn(topCard, wildColor: wildColor)) indices.add(i);
    }
    return indices;
  }

  bool hasPlayableCard(int playerIdx) => playableIndices(playerIdx).isNotEmpty;

  String? playCard(int playerIdx, int cardIdx, {UnoColor? chosenColor}) {
    if (gameOver) return 'Game over';
    if (playerIdx != currentPlayer) return 'Not your turn';
    final card = hands[playerIdx][cardIdx];
    if (card.isWild && chosenColor == null) return 'Select a color';
    if (!card.canPlayOn(topCard, wildColor: wildColor)) return 'Cannot play';

    hands[playerIdx].removeAt(cardIdx);
    discardPile.add(card);
    wildColor = card.isWild ? chosenColor : null;

    if (hands[playerIdx].isEmpty) { gameOver = true; winner = playerIdx; return null; }

    switch (card.type) {
      case UnoType.skip:
        _advance(); break;
      case UnoType.reverse:
        if (playerCount == 2) _advance(); else direction = -direction;
        break;
      case UnoType.draw2:
        _advance(); _drawCards(hands[currentPlayer], 2); break;
      case UnoType.wildDraw4:
        _advance(); _drawCards(hands[currentPlayer], 4); break;
      default: break;
    }
    _advance(); turnCount++;
    return null;
  }

  UnoCard? drawCard(int playerIdx) {
    if (gameOver || playerIdx != currentPlayer) return null;
    _ensureDrawPile();
    final card = drawPile.removeAt(0);
    hands[playerIdx].add(card);
    if (card.canPlayOn(topCard, wildColor: wildColor)) return card;
    _advance(); turnCount++;
    return null;
  }

  void passTurn() { _advance(); turnCount++; }

  void _drawCards(List<UnoCard> hand, int count) {
    for (int i = 0; i < count; i++) {
      _ensureDrawPile();
      hand.add(drawPile.removeAt(0));
    }
  }

  void _ensureDrawPile() {
    if (drawPile.isNotEmpty) return;
    if (discardPile.length <= 1) { drawPile = shuffledDeck(); return; }
    final top = discardPile.removeLast();
    drawPile = List.from(discardPile);
    discardPile.clear();
    discardPile.add(top);
    drawPile.shuffle(_rng);
  }

  void _advance() {
    currentPlayer = (currentPlayer + direction) % playerCount;
    if (currentPlayer < 0) currentPlayer += playerCount;
  }
}
