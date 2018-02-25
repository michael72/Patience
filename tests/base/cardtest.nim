import unittest

import base.card

suite "Check card":
  test "Check symbol":
    let c1 = createCard(Suit.diamonds, 1)
    check(c1.symbol() == 'A')
  test "Check subtraction":
    let ace = createCard(Suit.diamonds, 1) # Ace
    let king = createCard(Suit.spades, 13)  # King
    let two = createCard(Suit.hearts, 2)   # an actual 2
    check(abs(ace-king) == 1) # abs(Ace-King)
    check(abs(king-ace) == 1) # abs(King-Ace)
    check(abs(ace-two) == 1)
    check(abs(two-ace) == 1)
    check(abs(king-two) == 2)
    check(abs(two-king) == 2)
    check(abs(king-king) == 0)
