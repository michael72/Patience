import card
import pack
import sequtils
import future
import math
import tables
import hashes
import utils.debugmacros

type
  LayoutType* {.pure.} = enum
    cell, freecell, squared, fanned, stock, foundation

  FanOrientation* {.pure.} = enum
    none, leftRight, rightLeft, upBottom, bottomUp#[,
    leftUpBottomRight, leftBottomUpRight, rightUpBottomLeft, rightBottomUpLeft]#

  Position* = object
    col*: int
    row*: int

  LayoutPart* = ref object
    ltype*: LayoutType
    orientation*: FanOrientation
    angle*: int
    pos*: Position
    pack*: Pack

  Layout* = ref object
    parts*: seq[LayoutPart]
    partsByType*: Table[LayoutType,seq[LayoutPart]]
    partByPosition*: Table[Position,LayoutPart]
    minCol: int
    maxCol: int
    minRow: int
    maxRow: int

  Move* = object
    src*: int # index of LayoutPart in Layout
    dest*: int

  GameMove* = object
    layout*: Layout
    move*: Move
    rating*: int

proc hash*(pos: Position): int =
  pos.row * 1024 + pos.col

proc hash*(lt: LayoutType): int = (int)lt

proc createLayout*(parts: seq[LayoutPart]): Layout =
  var minCol = 1000
  var maxCol = 0
  var minRow = 1000
  var maxRow = 0
  for part in parts:
    minCol = min(minCol,part.pos.col)
    maxCol = max(maxCol,part.pos.col)
    minRow = min(minRow,part.pos.row)
    maxRow = max(maxRow,part.pos.row)
  var partsByType = initTable[LayoutType,seq[LayoutPart]]()
  var partByPosition = initTable[Position,LayoutPart]()
  for lt in LayoutType.cell..LayoutType.foundation:
    partsByType.add(lt, @[])
  
  for p in parts:
    partsByType[p.ltype].add(p)
    assert(not partByPosition.hasKey(p.pos), "Position used twice: " & $p.pos)
    partByPosition[p.pos] = p

  result = Layout(parts: parts, 
                  minCol: minCol, maxCol: maxCol, 
                  minRow: minRow, maxRow: maxRow,
                  partsByType: partsByType, partByPosition: partByPosition)


proc stringRep*(lp: LayoutPart): seq[string] = 
  result = @[]
  let cards = lp.pack.openedCards
  if len(cards) == 0:
    result.add("    ")
  elif len(cards) > 1 and 
    LayoutType.fanned == lp.ltype:
    var str = ""
    for c in cards:
      let part = "|" & $c & "|"
      case lp.orientation:
      of FanOrientation.leftRight:
        str = str & (if str == "" : part else: part[1..^1])
      of FanOrientation.rightLeft:
        str = (if str == "" : part else: part[0..^2]) & str
      of FanOrientation.upBottom:
        result.add(part)
      of FanOrientation.bottomUp:
        result.insert(part,0)
      of FanOrientation.none:
        assert(false, "Fan orientation none on layout type 'fanned' is not supported!")
        discard
      else:
        assert(false, "discarded orientation: " & $lp.orientation)
        discard
    if (str != ""):
      result.add(str)
  else:
    if LayoutType.foundation == lp.ltype:
      result.add("[" & $cards[^1] & "]")
    else:
      result.add("|"& $cards[^1] & "|")


proc fill(str: string, times: int): string = 
  result = ""
  for i in 1..times:
    result.add(str)

proc `$`*(layout: Layout): string = 
  var heights = repeat(0, layout.maxRow-layout.minRow+1)
  var widths = repeat(0, layout.maxCol-layout.minCol+1)
  var cells : seq[seq[seq[string]]] = @[]
  result = ""
  
  for rowIdx in 0..layout.maxRow-layout.minRow:
    let row = rowIdx+layout.minRow
    var cellRow: seq[seq[string]] = @[]
    for colIdx in 0..layout.maxCol-layout.minCol:
      let col = colIdx + layout.minCol
      var cell : seq[string] = @[]
      let pos = Position(col:col, row:row)
      if layout.partByPosition.hasKey(pos):
        let lp = layout.partByPosition[pos]
        cell = lp.stringRep()
        assert(len(cell) > 0, "wrong cell info for col " & $col & ", row " & $row)
        widths[colIdx] = max(widths[colIdx], len(cell[0]))
        heights[rowIdx] = max(heights[rowIdx], len(cell)) 
      cellRow.add(cell)
    cells.add(cellRow)

  for rowIdx in 0..layout.maxRow-layout.minRow:
    for y in 0..<heights[rowIdx]:
      for colIdx in 0..layout.maxCol-layout.minCol:
        let cell = cells[rowIdx][colIdx]
        let pos = Position(col:colIdx+layout.minCol, row:rowIdx+layout.minRow)
        if len(cell) > 0:
          let lp = layout.partByPosition[pos]
          let y2 =
            if lp.orientation == FanOrientation.bottomUp:
              heights[rowIdx]-1-y
            else: y
          let str = 
            if len(cell) > y2:
              cell[y2]
            else: ""
          let f = " ".fill(widths[colIdx]-len(str))
          let addstr =
            if lp.orientation == FanOrientation.rightLeft:
              f & str
            else:
              str & f
          result.add(addstr)
        else:
          result.add(" ".fill(widths[colIdx]))
      result.add("\n")

proc swap*(move: Move) : Move =
  Move(src:move.dest, dest:move.src)

proc `$`*(move: Move) : string =
  $move.src & " -> " & $move.dest

proc strRep(gm: GameMove, what: int) : string =
  let part = gm.layout.parts[what]
  let cardVal = 
    if part.pack.len() > 0:
      $part.pack.top
    else: "[]"
  $what & ":" & cardVal
    
proc `$`*(gm: GameMove) : string =
  gm.strRep(gm.move.src) & " -> " & gm.strRep(gm.move.dest) & "(" & $gm.rating & ")"
