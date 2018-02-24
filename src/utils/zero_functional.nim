import strutils, sequtils, macros, options, sets

const iteratorVariableName = "it"
const accuVariableName = "a"
const indexVariableName = "idx"

const internalIteratorName = "__" & iteratorVariableName & "__"
const useInternalAccu = accuVariableName != "result"
const internalAccuName = if (useInternalAccu): "__" & accuVariableName & "__" else: "result"
const emptyIdentifier = "__empty__"

type 
  ExtNimNode = ref object ## Store additional info the current NimNode used in the inline... functions
    node: NimNode     ## the current working node / the current function
    index: int        ## index used for the created iterator - 0 for the first 
    isLastItem: bool  ## true if the current item is the last item in the command chain
    initials: NimNode ## code section before the first iterator where variables can be defined
    finals: NimNode   ## code to set the final operations, e.g. the result
    listRef:  NimNode ## reference to the list the iterator is working on
    nextIndexInc: bool ## if set to true the index will be increment by 1 for the next iterator 
  
when false: #TODO not used at the moment 
  type
    FiniteIndexable[T] = concept a
      a.low is int
      a.high is int
      a[int] is T

static: # I can't concat sets, so I need to use var
  let SEQUENCE_HANDLERS = ["map", "indexedMap", "filter", "filterSeq", "mapSeq", "indexedMapSeq", "sub", "subSeq"].toSet
  var HANDLERS = ["zip", "exists", "any", "all", "index", "fold", "foreach", "find"].toSet
  HANDLERS.incl(SEQUENCE_HANDLERS)

proc zeroDsl*(node: NimNode): bool =
  node.kind == nnkCall and node[0].kind == nnkIdent and $node[0] in HANDLERS

proc toInternal(node: NimNode, base: NimNode): NimNode =
  if not zeroDsl(node):
    return if base.isNil: node else: nnkDotExpr.newTree(base, node)    
  let call = node[0].repr
  let callNode = ident("$1Internal" % call)
  if not base.isNil:
    result = nnkCall.newTree(nnkDotExpr.newTree(base, callNode))
  else:
    result = nnkCall.newTree(callNode)
  if call == "zip":
    var isArg = false
    for child in node:
      if isArg:
        result.add(child)
      else:
        isArg = true
  elif call in SEQUENCE_HANDLERS:
    let it = ident("it")
    let logic = node[1]
    let empty = newEmptyNode()
    let autoIdent = ident("auto")
    let handler = nnkLambda.newTree(
      empty,
      empty,
      empty,
      nnkFormalParams.newTree(autoIdent, nnkIdentDefs.newTree(it, autoIdent, empty)),
      empty,
      empty,
      logic)
    result.add(handler)

proc compileTimeTypeInfer(node: NimNode): NimNode =
  # zip(..), map(..) => zipInternal(..).mapInternal(..)
  result = nil
  for child in node:
    result = toInternal(child, result)

# internal functions: just have to return a valid non-nil sequence and typecheck
proc zipInternal*[T, U](a: seq[T], b: seq[U]): seq[(T, U)] =
  @[]

proc zipInternal*[T, U, V](a: seq[T], b: seq[U], c: seq[V]): seq[(T, U, V)] =
  @[]

proc zipInternal*[T, U, V, W](a: seq[T], b: seq[U], c: seq[V], d: seq[W]): seq[(T, U, V, W)] =
  @[]

proc mapInternal*[T, U](s: seq[T], handler: proc(element: T): U): seq[U] =
  @[]

proc indexedMapInternal*[T, U](s: seq[T], handler: proc(element: (int, T)): U): seq[U] =
  @[]

proc filterInternal*[T](s: seq[T], handler: proc(element: T): bool): seq[T] =
  @[]

proc filterSeqInternal*[T](s: seq[T], handler: proc(element: T): bool): seq[T] =
  @[]

proc subInternal*[T](s: seq[T], handler: proc(element: T): bool): seq[T] =
  @[]

proc subSeqInternal*[T](s: seq[T], handler: proc(element: T): bool): seq[T] =
  @[]
      
proc mapSeqInternal*[T, U](s: seq[T], handler: proc(element: T): U): seq[U] =
  @[]

proc indexedMapSeqInternal*[T, U](s: seq[T], handler: proc(element: (int, T)): U): seq[U] =
  @[]

proc zipInternal*[A, T, U](a: array[A, T], b: array[A, U]): array[A, (T, U)] =
  discard

proc zipInternal*[A, T, U, V](a: array[A, T], b: array[A, U], c: array[A, V]): array[A, (T, U, V)] =
  discard

proc zipInternal*[A, T, U, V, W](a: array[A, T], b: array[A, U], c: array[A, V], d: array[A, W]): seq[(T, U, V, W)] =
  discard

proc mapInternal*[A, T, U](a: array[A, T], handler: proc(element: T): U): array[A, U] =
  discard

proc indexedMapInternal*[A, T, U](a: array[A, T], handler: proc(element: (int, T)): U): array[A, U] =
  discard

proc filterInternal*[A, T](a: array[A, T], handler: proc(element: T): bool): array[A, T] =
  discard

proc subInternal*[A, T](a: array[A, T], handler: proc(element: T): bool): array[A, T] =
  discard

proc filterSeqInternal*[A, T](a: array[A, T], handler: proc(element: T): bool): seq[T] =
  @[]

proc subSeqInternal*[A, T](a: array[A, T], handler: proc(element: T): bool): seq[T] =
  @[]

proc mapSeqInternal*[A, T, U](a: array[A, T], handler: proc(element: T): U): seq[U] =
  @[]

proc indexedMapSeqInternal*[A, T, U](a: array[A, T], handler: proc(element: (int, T)): U): seq[U] =
  @[]

proc mapInternal*[U](a: typedesc[enum], handler: proc(element: a): U): seq[U] =
  @[]

proc filterInternal*(a: typedesc[enum], handler: proc(element: a): bool): seq[a] =
  @[]

proc newExtNode(node: NimNode, 
                   index: int, 
                   isLastItem: bool,
                   initials: NimNode,
                   finals: NimNode,
                   listRef: NimNode,
                   nextIndexInc = false): ExtNimNode =
  result = ExtNimNode(node: node, 
                      index: index, 
                      isLastItem: isLastItem,
                      initials: initials,
                      finals: finals,
                      listRef: listRef,
                      nextIndexInc: nextIndexInc)

proc clone(x: ExtNimNode): ExtNimNode {.compileTime.} =
    result = x.node.newExtNode(index = x.index, 
                               isLastItem = x.isLastItem, 
                               initials = x.initials,
                               finals = x.finals,
                               listRef = x.listRef,
                               nextIndexInc = x.nextIndexInc)

proc iterFunction: NimNode {.compileTime.} =
  let empty = newEmptyNode()
  result = nnkLambda.newTree(
    empty,
    empty,
    empty,
    nnkFormalParams.newTree(newIdentNode("auto")),
    empty,
    empty,
    nnkStmtList.newTree())

proc mkItNode(index: int) : NimNode {.compileTime.} = 
  newIdentNode(internalIteratorName & ("$1" % $index))

proc itNode(ext: ExtNimNode) : NimNode {.compileTime.} =
  result = mkItNode(ext.index)

proc prevItNode(ext: ExtNimNode) : NimNode {.compileTime.} =
  result = mkItNode(ext.index - 1)

proc res(ext: ExtNimNode): NimNode {.compileTime.} =
  result = newIdentNode("result")

proc adapt(ext: ExtNimNode, index=1, inFold=false): NimNode {.compileTime.} =
  let fun = ext.node[index]
  case fun.kind:
  of nnkIdent:
    if $fun == iteratorVariableName:
      return ext.prevItNode()
    elif inFold and useInternalAccu and $fun == accuVariableName:
      return newIdentNode(internalAccuName)
    else:
      return fun
  of nnkFloatLit..nnkFloat128Lit, nnkCharLit..nnkUInt64Lit, nnkStrLit..nnkTripleStrLit, nnkSym:
    return fun
  else:
    for z in 0..<fun.len:
      let son = ext.clone()
      son.node = fun
      fun.add(son.adapt(index=z, inFold=inFold))
    fun.del(0, fun.len div 2)
    return fun

proc getStmtList(node: NimNode, removeNil = true): NimNode =
  var child = node
  while child.len > 0:
    child = child[^1]
    if child.kind == nnkStmtList:
      if removeNil:
        if child.len > 0 and child[^1].kind == nnkNilLit:
          child.del(1,1)
      return child
  return nil
    
proc inlineZip(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  let itIdent = ext.itNode()
  let idxIdent = newIdentNode(indexVariableName)
  let m = nnkCall.newTree(newIdentNode("min"), nnkBracket.newTree())
  let p = nnkPar.newTree()
  var z = 0
  for arg in ext.node:
    if z > 0:
      m[^1].add(nnkCall.newTree(newIdentNode("high"), arg))
      p.add(nnkBracketExpr.newTree(arg, idxIdent))
    z += 1
  ext.node = quote:
    let minHigh = `m`
    for `idxIdent` in 0..minHigh:
      let `itIdent` = `p`
  ext.nextIndexInc = true
  result = ext

proc inlineMap(ext: ExtNimNode, indexed: bool = false, toSeq: bool = false): ExtNimNode {.compileTime.} =
  let itIdent = ext.itNode()
  let adaptedF = ext.adapt()
  let idxIdent = newIdentNode(indexVariableName)
  var next: NimNode
  if indexed:
    next = quote:
      (`idxIdent`, `adaptedF`)
  else:
    next = adaptedF

  if ext.isLastItem:
    let resultIdent = ext.res
    if not toSeq:
      ext.node = quote:
        when `resultIdent` is array:
          `resultIdent`[`idxIdent`] = `next`
        else:
          `resultIdent`.add(`next`)
    else:
      let emptyIdent = newIdentNode(emptyIdentifier)
      ext.node = quote:
        if `emptyIdent`:
          `emptyIdent` = false
          `resultIdent` = @[`next`]
        else:
          `resultIdent`.add(`next`)
  else:
    ext.node = quote:
      let `itIdent` = `next`
  ext.nextIndexInc = true
  result = ext

proc inlineFilter(ext: ExtNimNode, toSeq: bool = false): ExtNimNode {.compileTime.} =
  let adaptedTest = ext.adapt()
  if ext.isLastItem:
    let resultIdent = ext.res
    let itPrevIdent = ext.prevItNode()
    let idxIdent = ident(indexVariableName)
    var push: NimNode
    if not toSeq:
      push = quote:
        when `resultIdent` is array:
          `resultIdent`[`idxIdent`] = `itPrevIdent`
        else:
          `resultIdent`.add(`itPrevIdent`)
    else:
      let emptyIdent = newIdentNode(emptyIdentifier)
      push = quote:
        if `emptyIdent`:
          `emptyIdent` = false
          `resultIdent` = @[`itPrevIdent`]
        else:
          `resultIdent`.add(`itPrevIdent`)
    ext.node = quote:
      if `adaptedTest`:
        `push`
  else:
    ext.node = quote :
        if `adaptedTest`:
          nil
  result = ext

proc inlineSub(ext: ExtNimNode, toSeq: bool = false): ExtNimNode {.compileTime.} =
  # sub is re-routed as filter implementation
  let index = newIdentNode(indexVariableName)
  let minIndex = ext.node[1]
  var newCheck: NimNode
  if ext.node.len == 2:
    newCheck = quote:
      `index` >= `minIndex`
  else:
    var endIndex = ext.node[2]
    if repr(endIndex)[0] == '^':
      let listRef = ext.listRef
      let endIndexAbs = endIndex[^1]
      endIndex = quote:
        len(`listRef`)-`endIndexAbs` # backwards index only works with collections that have a len
    newCheck = quote:
      `index` >= `minIndex` and `index` < `endIndex`
  ext.node = newCall("filter", newCheck)
  return ext.inlineFilter(toSeq)

proc inlineExists(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  let adaptedTest = ext.adapt()
  let resultIdent = ext.res
  let i = quote:
    `resultIdent` = false
  ext.initials.add(i)
  ext.node = quote:
    if `adaptedTest`:
      return true
  result = ext

proc inlineFind(ext: ExtNimNode): ExtNimNode {.compileTime.} = 
  let adaptedTest = ext.adapt()
  let resultIdent = ext.res
  let itIdent = ext.prevItNode()
  ext.node = quote:
    if `adaptedTest`:
      return some(`itIdent`)
    else:
      `resultIdent` = none(`itIdent`.type) # TODO: this should be optimized
  result = ext

proc inlineAll(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  let adaptedTest = ext.adapt()
  let resultIdent = ext.res
  let i = quote:
    `resultIdent` = true
  ext.initials.add(i)
  ext.node = quote:
    if not `adaptedTest`:
      return false
  result = ext

proc inlineForeach(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  var adaptedExpression = ext.adapt()
  if adaptedExpression.kind == nnkExprEqExpr and $adaptedExpression[0] == $ext.prevItNode():
    let rightSide = adaptedExpression[^1]
    let listRef = ext.listRef
    let index = newIdentNode(indexVariableName) 
    ext.node = quote:
      # changing the iterator content will only work with indexable + variable containers
      `listRef`[`index`] = nil
    for idx,child in ext.node:
      if child.kind == nnkNilLit:
        ext.node[idx] = rightSide
        break
  else:
    ext.node = quote:
      `adaptedExpression`
  result = ext
      
proc inlineIndex(ext: ExtNimNode): ExtNimNode{.compileTime.} =
  let adaptedTest = ext.adapt()
  var idxIdent = newIdentNode(indexVariableName)
  var resultIdent = ext.res
  let i = quote:
    `resultIdent` = -1 # index not found
  ext.initials.add(i)
  ext.node = quote:
    if `adaptedTest`:
      return `idxIdent` # return index
  result = ext  

proc inlineFold(ext: ExtNimNode): ExtNimNode{.compileTime.} =
  let initialValue = ext.node[1]
  let resultIdent = ext.res
  let foldOperation = ext.adapt(index=2, inFold=true)

  var i : NimNode 
  if useInternalAccu:
    let accuIdent = newIdentNode(internalAccuName) 
    i = quote:
      var `accuIdent` = `initialValue`
    ext.node = quote:
      `accuIdent` = `foldOperation`
    let f = quote:
      `resultIdent` = `accuIdent`
    ext.finals.add(f)
  else:
    i = quote:
      `resultIdent` = `initialValue`
    ext.node = quote:
      `resultIdent` = `foldOperation`
  
  ext.initials.add(i)
  result = ext

proc inlineSeq(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  let itIdent = ext.itNode()
  let node = ext.node
  ext.node = quote:
    for `itIdent` in `node`:
      nil
  ext.nextIndexInc = true
  result = ext
  
proc ensureLast(ext: ExtNimNode) {.compileTime.} =
  if not ext.isLastItem:
    error("$1 can be only last in a chain" % $ext.node[0], ext.node)

proc ensureFirst(ext: ExtNimNode) {.compileTime.} =
  if ext.index > 0:
    error("$1 supposed to be first" % $ext.node[0], ext.node)

proc ensureParameters(ext: ExtNimNode, no: int) {.compileTime.} = 
    if ext.node.len <= no:
      error($ext.node[0] & " needs at least $1 parameter(s)" % $no, ext.node)
        
proc inlineElement(ext: ExtNimNode): ExtNimNode {.compileTime.} =
  if ext.node.kind == nnkCall:
    ext.ensureParameters(1)
    let label = $ext.node[0]
    case label:
    of "zip":
        ext.ensureFirst()
        return ext.inlineZip()
    of "map":
      return ext.inlineMap()
    of "filter":
      return ext.inlineFilter()
    of "exists":
      ext.ensureLast()
      return ext.inlineExists()
    of "find":
      ext.ensureLast()
      return ext.inlineFind()
    of "all":
      ext.ensureLast()
      return ext.inlineAll()
    of "index":
      ext.ensureLast()
      return ext.inlineIndex()
    of "indexedMap":
      return ext.inlineMap(indexed=true)
    of "fold":
      ext.ensureLast()
      ext.ensureParameters(2)
      return ext.inlineFold()
    of "foreach":
      return ext.inlineForeach()
    of "any":
      warning("any is deprecated - use exists instead")
      return ext.inlineExists()
    of "filterSeq":
      return ext.inlineFilter(toSeq=true)
    of "mapSeq":
      return ext.inlineMap(toSeq=true)
    of "indexedMapSeq":
      return ext.inlineMap(indexed=true, toSeq=true)
    of "sub":
      return ext.inlineSub()
    of "subSeq":
      return ext.inlineSub(toSeq=true)
    else:
      error("$1 is unknown" % label, ext.node)    
  else:
    ext.ensureFirst()
    return ext.inlineSeq()

proc iterHandler(args: NimNode, debug=false): NimNode {.compileTime.} =
  result = iterFunction()
  var code = result[^1]
  let initials = nnkStmtList.newTree()
  result[^1].add(initials)
  var forceSeq = false

  let defineIdxVar = args[0].len == 0 or (args[0][0].kind == nnkIdent and $args[0][0] != "zip")
  if defineIdxVar:
    let idxIdent = newIdentNode(indexVariableName)
    let identDef = quote:
      var `idxIdent` = 0 
    result[^1].add(identDef)

  if args.len > 0 and args[^1].len > 0:
    let lastCall = $args[^1][0]
    if lastCall in SEQUENCE_HANDLERS:
      forceSeq = lastCall.endsWith("Seq")
      let resultIdent = newIdentNode("result")
      let zero =
        if not forceSeq:
          let resultType = compileTimeTypeInfer(args)
          quote:
            `resultIdent` = `resultType`
        else:
          let emptyIdent = newIdentNode(emptyIdentifier)
          quote:
            var `emptyIdent` = true

      result[^1].add(zero)

  var index = 0
  let listRef = args[0]
  let finals = nnkStmtList.newTree()
  
  for arg in args:
    let last = arg == args[^1]
    let ext = arg.newExtNode(index, last, initials, finals, listRef).inlineElement()
    let newCode = ext.node.getStmtList()
    code.add(ext.node)
    if newCode != nil:
      code = newCode
    if ext.nextIndexInc:
      index += 1
  if finals.len > 0:
    result[^1].add(finals)

  proc findForNode(node: NimNode) : NimNode = 
    if node.kind == nnkForStmt:
      return node
    for child in node:
      let res = child.findForNode()
      if res != nil:
        return res
    return nil

  if defineIdxVar:
    let forNode = result.findForNode()
    if forNode != nil:
      # add index increment to end of the for loop
      let idxIdent = newIdentNode(indexVariableName)
      let incrIdx = quote:
        `idxIdent` += 1
      forNode[^1].add(incrIdx)

  if (debug):
    echo(repr(result))
    # for the whole tree do:
    # echo(treeRepr(result))
    
  result = nnkCall.newTree(result)

macro connect*(args: varargs[untyped]): untyped =
  result = iterHandler(args)

proc delegateMacro(a: NimNode, b:NimNode, debug=false): NimNode =
  expectKind(b, nnkCall)
  let methods = b
  var m: seq[NimNode] = @[]
  var node = methods
  while node.kind == nnkCall:
    if node[0].kind == nnkDotExpr:
      m.add(nnkCall.newTree(node[0][^1]))
      var z = 0
      for b in node:
        if z > 0:
          m[^1].add(b)
        z += 1
      node = node[0][0]
    elif node[0].kind == nnkIdent:
      m.add(node)
      break
    else:
      break
  var m2: seq[NimNode] = @[a]
  for z in countdown(high(m), low(m)):
    m2.add(m[z])
  let mad = nnkArgList.newTree(m2)
  result = iterHandler(mad, debug)

macro `-->`*(a: untyped, b: untyped): untyped =
  result = delegateMacro(a,b)

## use this macro for debugging - will output the created code
macro `-->>`*(a: untyped, b: untyped): untyped =
  result = delegateMacro(a,b,true)
