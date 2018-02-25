import base.layout
import base.pack
import base.card
import utils.zero_functional
import games.gamebase
import strutils

proc display_move(g: GameBase, idx: int, move: Move) =
  let lpSrc = g.layout.parts[move.src]
  let lpDest = g.layout.parts[move.dest]
  let dest =
    if lpDest.pack.len > 0:
      $lpDest.pack.top
    else:
      "empty position " & $move.dest & " (" & $lpDest.ltype & ")" 
      
  let msg = $idx & ": " & $lpSrc.pack.top & " -> " & dest
  echo($msg)

proc perform_undo(game: GameBase, doneMoves: var seq[Move]) =
  let last = doneMoves[^1].swap()
  if game.performMove(last, force=true):
    doneMoves.del(doneMoves.len-1)

proc play_game*(g: GameBase) =
  var game = g
  var doneMoves: seq[Move] = @[]

  while true:
    echo($game)
    let moves : seq[Move] = game.availableMoves()
    if moves.len > 0:
      moves --> foreach(game.display_move(idx, it))
    elif game.finished():
      echo("Hooray: game is finished!")
    else:
      echo("Du-dumm: no more moves available!")

    echo("select - q = quit, u = undo, n = new game, r = restart same game") # a = autoPlay, 
    let chk = readLine(stdin)
    case chk
    of "n":
      game = game.reset()
      doneMoves = @[]
    of "q":
      break
    of "u":
      if doneMoves.len > 0:
        game.perform_undo(doneMoves)
      else:
        echo("what's there to undo?!")
    of "r":
      if doneMoves.len > 0:
        while doneMoves.len > 0:
          game.perform_undo(doneMoves)
      else:
        echo("what's there to reset?!")      
    of "a":
      let moves = game.autoPlay()
      if moves.len == 0:
        echo("not solvable!")
      else:
        echo("found solution in " & $moves.len & " moves!")
        echo(moves)
    else:
      try:
        let res = chk.parseInt()
        echo("performing " & $res)
        let x = game.performMove(moves[res])
        if x:
          doneMoves.add(moves[res])
      except ValueError:
        echo("Don't know what you mean - " & $chk & "?")
        echo("Enter number or command")
