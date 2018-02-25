import sequtils
import strutils
import random
import future
import times
import utils.rand
import utils.debugmacros
import utils.zero_functional
import options

type
  Suit* {.pure.} = enum
    diamonds = (0, "D"),
    hearts = (1, "H"), 
    spades = (2, "S"), 
    clubs = (3, "C")
  CardColor* {.pure.} = enum
    red, black
  
type 
  Card* = ref object
    id: int # [suit | value]
    opened: bool

const CardSymbols = "?A23456789XJQK??"

proc createCard*(suit: Suit, value: int, opened: bool = false) : Card =
  Card(id: (((int)suit) shl 4) + value, opened: opened)  

proc suit*(card: Card) : Suit {.inline.}  = (Suit)(card.id shr 4)
proc value*(card: Card): int {.inline.} = (card.id and 0xF)
proc id*(card: Card): int {.inline.} = card.id
proc symbol*(card: Card): char =
  let cardTypes = CardSymbols
  result = cardTypes[card.value]
proc color*(card: Card): CardColor =
  if (card.suit == Suit.diamonds or
    card.suit == Suit.hearts):
    return CardColor.red
  return CardColor.black
proc open*(card: Card) =
  card.opened = true
proc close*(card: Card) =
  card.opened = false
proc opened*(card: Card) : bool = card.opened

proc `$`*(card: Card): string = 
  if card.opened:
    card.symbol & $(card.suit)
  else:
    "[]"

proc `-`*(card1: Card, card2: Card): int {.inline} =
  var diff = card1.value - card2.value
  if diff < -6:
    diff += 13
  elif diff > 6:
    diff -= 13
  result = diff

proc abs*(card1: Card, card2: Card): int {.inline.} =
  abs(card1 - card2)

proc diff*(card1: Card, card2: Card): int {.inline.} =
  result = abs(card1.id - card2.id)
  if result == 12 and card1.suit == card2.suit: # special case Ace=14 - 2
    result = 1

proc createCardFrom*(strValue: string) : Card =
  let strSymbol = strValue[0]
  let strSuit = strValue[1..1]
  let suit = Suit --> find($it == strSuit)
  let value = CardSymbols.find(strSymbol)
  result = Card(id: (((int)suit.get()) shl 4) + value, opened: true)  
    
    
   