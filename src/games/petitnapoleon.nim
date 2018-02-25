import base.layout
import base.pack
import base.card
import sequtils
import strutils
import algorithm
import future
import tables
import parseutils
import os
import times
import utils.debugmacros
import utils.zero_functional
import gamebase

type
  ForceDirection* {.pure.} = enum
    noDirection, up, down

type
  PetitNapoleon* = ref object of GameBase
    forceDirection: ForceDirection

type
  CheckResult {.pure.} = enum
    ok = (0, "OK"),
    moveFromEmpty = (1, "Cannot move from empty cell"),
    cellarInUse = (2, "Cellar already used"),
    cannotAddCellarRows = (3, "Cannot add to cellar adjoining rows"),
    sameSuit = (4, "Cards must have same suit"),
    ascendOrDescend = (5, "Cards must be in ascending or descending order"),
    foundationSameOrder = (6, "Cards on the foundations must be all in ascending or in descending order"),
    unnecessaryMove = (7, "This move is completely unnecessary!"),
    cannotClearCellar = (8, "Cannot clear cellar when both adjoining rows contain cards"),
    cannotRemoveFromFoundation = (9, "Cannot remove from foundation")

#[
PetitNapoleon game layout by row:
0 <--3 4 5-->
..
3 <--3 4 5-->
4  <-3 4 5-> # cellar row

]#
const leftCol = 3
const centerCol = leftCol+1
const rightCol = centerCol+1
const firstRow = 0
const lastRow = firstRow+4
const cellarRow = lastRow

proc fanOrientation(col: int): FanOrientation =
  result =
    if col <= leftCol: FanOrientation.rightLeft
    elif col >= rightCol:  FanOrientation.leftRight
    else:  FanOrientation.none

proc layoutType(col: int, row: int): LayoutType =
  result = case col:
  of centerCol:   
    if row == lastRow:
      LayoutType.cell
    else:
      LayoutType.foundation
  else: LayoutType.fanned

proc create*() : PetitNapoleon =
  var parts: seq[LayoutPart] = @[]

  var pack = createPack(52, opened=true).shuffle
  # first value determines the value of the center cards
  let firstVal = pack.bottom.value()
  var centerCards = pack.split(c => c.value() == firstVal)

  assert(len(centerCards) == 4)
  assert(len(pack) == 48)

  for row in firstRow..lastRow:
    for col in leftCol..rightCol:
      let diff = if row == lastrow: -1 else: 0
      let numCards = 
        if col == centerCol: 1+diff
        else: 5+diff

      var newPack = createPack()
      if col == centerCol:
        centerCards.moveTo(newPack, numCards=numCards)
      else:
        pack.moveTo(newPack, numCards=numCards)#
      parts.add(LayoutPart(ltype: layoutType(col,row), orientation: col.fanOrientation, 
                           angle: 0, pos: Position(col:col, row:row), pack:newPack))
  result = PetitNapoleon(layout: createLayout(parts), forceDirection: ForceDirection.noDirection)

proc clone*(game: PetitNapoleon) : PetitNapoleon =
  let cp = create()
  zip(cp.layout.parts, game.layout.parts) --> 
    foreach(it[0].pack.copy(it[1].pack))
  result = cp

## for internal calculations: normalize means setting the foundation cards to aces
proc normalize*(game: PetitNapoleon) : PetitNapoleon =
  let cp = create()
  let midValue = game.layout.partsByType[LayoutType.foundation][0].pack.bottom.id

  proc copyCardsTo(packSrc: Pack, packDest: Pack) =
    packDest.clear()
    packSrc --> 
      foreach(packDest.add(createCard(it.suit, it.value-midValue+1, it.opened)))
  
  zip(game.layout.parts, cp.layout.parts) --> 
    foreach(it[0].pack.copyCardsTo(it[1].pack))
 
  result = cp

method createFrom*(g: var PetitNapoleon, savedString: string)  =
  var game = g
  for p in game.layout.parts:
    p.pack.clear
  var i = 0

  proc addCards(cardsStr: string, reverse: bool = false) =
    let cards = cardsStr.split("|")
    for c in cards:
      if c.len == 2:
        let card = createCardFrom(c)
        let p = game.layout.parts[i].pack
        if reverse:
          p.insert(card,0)
        else:
          p.add(card)

  for line in savedString.splitLines():
    let midIdx = line.find("[")
    let rightSide = line.find("|", if midIdx != -1: midIdx else: line.rfind("  |"))
    let leftSide = line.find("|")
    if leftSide != -1 and leftSide < rightSide:
      let leftEnd = if midIdx != -1: midIdx-1 else: rightSide - 1
      addCards(line[leftSide..leftEnd], reverse=true)
    i.inc
    if midIdx != -1:
      addCards(line[midIdx+1..midIdx+2])
    i.inc
    if rightSide != -1:
      addCards(line[rightSide..^1])
    i.inc

const cellarIndex = (cellarRow-firstRow) * (rightCol-leftCol+1) + 1
const cellarLeft = cellarIndex - 1
const cellarRight = cellarIndex + 1

{.push inline.}
proc mpart*(game: PetitNapoleon, idx: int) : var LayoutPart =
  game.layout.parts[idx]

proc mpack*(game: PetitNapoleon, idx: int): var Pack =
  game.mpart(idx).pack

proc empty*(game: PetitNapoleon, idx: int): bool  =
  game.mpack(idx).len() == 0

proc top*(game: PetitNapoleon, idx: int): Card   =
  game.mpack(idx).top

method `$`*(game: PetitNapoleon): string  =
  $game.layout

proc hasEmptyCellarRow*(game: PetitNapoleon): bool   =
  #game.empty(cellarLeft) or game.empty(cellarRight)
  (game.layout.parts[cellarLeft].pack.len == 0) or (game.layout.parts[cellarRight].pack.len == 0)

{.pop.}

proc checkFoundationMove(game: PetitNapoleon, move: Move, checkResult: var CheckResult) =
  let dest = game.mpart(move.dest)
  if (dest.ltype == LayoutType.foundation):
    if (dest.pack.len() == 1):
        # only first card to add to a foundation is critical
        # the first card determines the direction
        # all other cards on the foundation must follow that direction
        let actualDir = game.top(move.src) - game.top(move.dest) #cardSrc - cardDest
        case game.forceDirection:
          of ForceDirection.up: 
            if actualDir == -1:
              checkResult = CheckResult.foundationSameOrder
          of ForceDirection.down: 
            if actualDir == 1:
              checkResult = CheckResult.foundationSameOrder
          of ForceDirection.noDirection:
            for foundation in game.layout.partsByType[LayoutType.foundation]:
              if foundation.pack.len() > 1:
                let dir = foundation.pack.top - foundation.pack.next
                if dir != actualDir:
                  checkResult = CheckResult.foundationSameOrder
              break        

proc checkCellarMove(game: PetitNapoleon, move: Move, checkResult: var CheckResult) =
  if (move.dest == cellarIndex):
    if not game.empty(cellarIndex):
      checkResult = CheckResult.cellarInUse
  elif (move.dest >= cellarLeft):
    checkResult = CheckResult.cannotAddCellarRows

  if game.mpart(move.src).ltype == LayoutType.cell:
    if not game.hasEmptyCellarRow():
      checkResult = CheckResult.cannotClearCellar

proc checkMove*(game: PetitNapoleon, move: Move) : CheckResult =
  result = CheckResult.ok
  
  if game.empty(move.src):
    result = CheckResult.moveFromEmpty
  elif (game.mpart(move.src).ltype == LayoutType.foundation):
    result = CheckResult.cannotRemoveFromFoundation
  else:
    let src = game.mpart(move.src)

    game.checkCellarMove(move, result)
    if result == CheckResult.ok:
      if not game.empty(move.dest):
        # check for regular move
        let cardSrc = game.top(move.src)
        let cardDest = game.top(move.dest)
        if cardSrc.suit != cardDest.suit:
          result = CheckResult.sameSuit
        elif abs(cardSrc-cardDest) != 1:
          result = CheckResult.ascendOrDescend
        else: 
          game.checkFoundationMove(move, result)
      else:
        # move to empty row from a row that gets empty
        if (src.pack.len == 1) and ((move.src >= cellarLeft) or (move.dest < cellarLeft)):
          result = CheckResult.unnecessaryMove

proc availableMovesInt*(game: PetitNapoleon) : seq[Move] =
  var move = Move(src:0,dest:0)
  result = @[] 
  for src in 0..<game.layout.parts.len():
    for dest in src+1..<game.layout.parts.len():
      move.src = src
      move.dest = dest
      if game.checkMove(move) == CheckResult.ok:
        result.add(move) 
      let rev = move.swap()
      if game.checkMove(rev) == CheckResult.ok:
        result.add(rev)

proc setForceDirection(game: PetitNapoleon, dest: LayoutPart) =
  if (game.forceDirection == ForceDirection.noDirection):
    game.forceDirection = 
      if (dest.pack.top - dest.pack.next) == 1:
        ForceDirection.up
      else:
        ForceDirection.down

proc resetForceDirection(game: PetitNapoleon) =
    var allOne = true
    for foundation in game.layout.partsByType[LayoutType.foundation]:
      if foundation.pack.len() > 1:
        allOne = false
        break
    if allOne:
      game.forceDirection = ForceDirection.noDirection

proc performMoveInt(game: PetitNapoleon, move: Move, force: bool = false): bool {.inline.} = 
  result = force or (game.checkMove(move) == CheckResult.ok)
  if result:
    let src = game.mpart(move.src) 
    let dest = game.mpart(move.dest)
    src.pack.moveTo(dest.pack,-1)
    if not force and (dest.ltype == LayoutType.foundation):
      game.setForceDirection(dest)
    elif force and (src.ltype == LayoutType.foundation):
      game.resetForceDirection()

proc finishedInt(game: PetitNapoleon): bool {.inline.} =
  game.layout.partsByType[LayoutType.foundation] --> all(it.pack.len == 13)
  
method performMove*(game: PetitNapoleon, move: Move, force: bool = false): bool {.inline.} =
  game.performMoveInt(move, force)

method finished*(game: PetitNapoleon): bool {.inline.} =
  game.finishedInt()

method reset*(_: PetitNapoleon): GameBase = 
  create()

method availableMoves*(g: PetitNapoleon): seq[Move] =
  g.availableMovesInt()

method autoPlay*(g: PetitNapoleon): seq[Move] = quit "not yet available"
  

when isMainModule:
  import view.ascii.consolegame

  let game = create()
  game.play_game()
