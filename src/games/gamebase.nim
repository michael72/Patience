import base.layout

type
    GameBase* = ref object of RootObj
      layout*: Layout

method `$`*(g: GameBase): string {.base,inline.} = nil 

method reset*(g: GameBase): GameBase {.base.} = quit "must be overridden"

method availableMoves*(g: GameBase): seq[Move] {.base.} = nil

method performMove*(g: GameBase, move: Move, force: bool = false): bool {.base.} = false

method autoPlay*(g: GameBase): seq[Move] {.base.} = nil

method finished*(g: GameBase): bool {.base.} = false

method createFrom*(g: var GameBase, savedString: string) {.base.} = quit "must be overridden"

