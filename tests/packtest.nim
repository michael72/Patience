import unittest

import ../src/pack

suite "Check card pack":
  test "check createPack for known sizes":
    for sz in @[0, 32, 52, 104]:
      let pack = createPack(sz)
      check(sz == pack.len)
    test "check createPack for some unsupported sizes":
      for sz in @[1, 31, 51, 103, 200, -1, 255]:
        test "check createPack for invalid size " & $(sz):
          expect AssertionError:
            let pack = createPack(sz)
            check(len(pack) == 0)
  test "Check span":
    let cards = createPackFrom("QH|KH|AH|2H|3H")
    check(cards.hasSpan == true)
    check(cards.isSpan == true)
  test "Check span2":
    let cards = createPackFrom("AS|2S")
    check(cards.hasSpan == true)
    check(cards.isSpan == true)
  test "Check span3":
    let cards = createPackFrom("2S|3S|4S")
    check(cards.hasSpan == true)
    check(cards.isSpan == true)
  test "Check nospan":
    let cards = createPackFrom("2S|3H|4S")
    check(cards.hasSpan() == false)
    check(cards.isSpan() == false)
  test "Check has span but is no span":
    let cards = createPackFrom("2S|3H|4H")
    check(cards.hasSpan() == true)
    check(cards.isSpan() == false)

