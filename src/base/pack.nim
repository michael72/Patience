import sequtils
import strutils
import future
import times
import utils.rand
import utils.zero_functional
import card
import system

type
  Pack* = ref object
    cards: seq[Card]

proc shuffle*(self: Pack) : Pack =
  var shuffled: seq[Card] = @[]
  var orig = self.cards
  var i = orig.len
  while i > 0:
    let shuf = rand(i-1)
    let c = orig[shuf]
    orig.del(shuf)
    shuffled.add(c) 
    i -= 1
  result = Pack(cards: shuffled)

proc `$`*(self: Pack): string =
  result = "["
  result.add(self.cards.join("|"))
  result.add("]")

{.push inline.}
{.push noSideEffect.}
type CardsIndex = int or BackwardsIndex
proc `[]`(pack: Pack, i: CardsIndex): Card  =
  pack.cards[i]
  
proc top*(pack: Pack): Card =
  pack.cards[^1]

proc next*(pack: Pack): Card =
  pack.cards[^2]

proc bottom*(pack: Pack): Card =
  pack.cards[0]

proc len*(pack:Pack) : int =
  pack.cards.len

iterator items*(a: Pack): Card =
  ## iterates over each item of `a`.
  var i = 0
  let L = len(a)
  while i < L:
    yield a[i]
    inc(i)
    assert(len(a) == L, "seq modified while iterating over it")

proc isSpan*(pack: Pack): bool =
  pack.len > 0 and (
    pack -->
        sub(1)
        .all((pack[0].suit == pack[idx].suit) and
             (1 == pack[idx-1].abs(pack[idx])))) 

proc hasSpan*(pack: Pack): bool =
  result = ((pack.len > 1) and 
            (abs(pack[^1] - pack[^2]) == 1) and
            (pack[^1].suit == pack[^2].suit))

{.pop.} # noSideEffect

proc `[]=`(pack: Pack, i: CardsIndex, c:Card)  =
  pack.cards[i] = c

proc clear*(pack: Pack) =
  if nil == pack.cards:
    pack.cards = @[]
  else:
    pack.cards.setLen(0)
proc insert*(pack: Pack, card: Card, pos: int) =
  pack.cards.insert(card, pos)
proc add*(pack: Pack, card: Card) =
  pack.cards.add(card)
proc take*(pack: Pack): Card =
  pack.cards.pop
proc remove*(pack: Pack, pos: int) : Card = 
  pack.cards.del(pos)

proc copy*(pack: Pack, other: Pack) =
  pack.cards.setLen(0)
  pack.cards.add(other.cards)
            
proc swap*(pack: Pack) =
  for i in 0..(pack.len-1) shr 1:
    let c = pack[i]
    pack[i] = pack[pack.len-i-1]
    pack[pack.len-i-1] = c

{.pop.} # inline.

proc openedCards*(pack: Pack) : seq[Card] =
  pack.cards.filter(c => c.opened())

proc createPack*(numCards: int = 0, opened = false): Pack =
  var cards: seq[Card] = @[]
  if numCards != 0:
    let minCard : int =
      case numCards
      of 32: 7
      of 52: 2
      of 104: 2
      else: assert(false, "Wrong number of cards - expected 0, 32, 52 or 104"); -1

    let factor = 
      if numCards > 52: 2
      else: 1

    var values = @[1]
    for value in minCard..13:
      values.add(value)
    for value in values:
      for suit in Suit.items:
        for f in 1..factor:
          let card = suit.createCard(value, opened)          
          cards.add(card)

  result = Pack(cards: cards)

proc createPackFrom*(strValue: string) : Pack =
  result = createPack()
  for c in strValue.split("|"):
    result.add(createCardFrom(c))
 
proc moveTo*(src: Pack, dest: Pack, srcPos: int = 0, numCards: int = 1) =
  let realPos = if srcPos >= 0: srcPos else: len(src.cards) + srcPos
  assert(realPos + numCards <= len(src.cards), "srcPos: " & $srcPos & ", numCards: " & $numCards & ",len(src.cards): " & $len(src.cards) )
  var cnt = numCards
  while cnt > 0:
    dest.cards.add(src.cards[realPos])
    src.cards.del(realPos)
    cnt.dec

proc take*(pack: Pack, numCards: int = 1) : Pack =
  result = createPack()
  pack.moveTo(result, numCards=numCards)
  
proc split*(pack: Pack, pred: proc (card: Card): bool {.closure.}) : Pack =
  result = createPack()
  var i = 0
  var lenCards = len(pack.cards)
  while (i < lenCards):
    if pred(pack.cards[i]):
      pack.moveTo(result, i, 1)
      dec(lenCards)
    else:
      inc(i)

