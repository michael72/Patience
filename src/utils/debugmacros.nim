import macros
import strutils

## Name of th local string variable used in the debugmacros
const tmpVar = "__mkDbgStr_tmp__"
const varDivider = ", "
const nameValDivider = "="
const defValuesDivider = ": " 

proc mkDbgStr(params: NimNode) : seq[NimNode] =
  ## Helper proc that creates a local string variable and attaches
  ## the parameters to it.
  ## String literals are simply attached to the local variable,
  ## Variables are attached by name and their contents converted to string.
  var stmtList : seq[NimNode] = @[]
  if len(params) > 0:
    var divider = ""
    # create a temporary variable
    stmtList.add(newNimNode(nnkVarSection).add(
      newIdentDefs(ident(tmpVar), ident("string"), newLit(""))))

    proc append(nodes: varargs[NimNode]) =
      for n in nodes:
        # appends substrings to the temporary variable
        stmtList.add(newCall(newDotExpr(ident(tmpVar), ident("add")), n))

    for par in params:
      if par.kind == nnkStrLit:
        # append string literal as is
        append(newLit(divider), par)
        divider = defValuesDivider;
      else:
        # append variable name and content
        var varName = repr(par)
        # transform b(a) to a.b
        if varName.endswith(")"):
          let idx = varName.find("(")
          if idx != -1 and varName.find(",") == -1:
            varName = varName[idx+1..^2] & "." & varName[0..idx-1]
        append(newLit(divider), newLit(varName), newLit(nameValDivider), prefix(par, "$"))
        divider = varDivider
  result = stmtList


macro dbgString*(params:varargs[typed]) : untyped = 
  ## Creates a string from the given variable and string parameters
  ## Example
  ## var a = 1; var b = 2
  ## let s = dbgString(a,b)
  ## # s = "a=1, b=2"
  result = newBlockStmt(
    newNimNode(nnkStmtList).
      add(mkDbgStr(params)).
      add(ident(tmpVar)))
  

macro dbgEcho*(params:varargs[typed]) : untyped =
  ## Echos the string parameters and variable names with values to the console.
  ## Example:
  ## var x = 123; var y = 456
  ## dbgEcho("Test", x, y)
  ## > Test: x=123, y=456
  var stmtList = newNimNode(nnkStmtList)
  let dbgStr = mkDbgStr(params)
  stmtList.
    add(dbgStr).
    add(newCall(ident("echo"),
      if len(dbgStr) > 0: ident(tmpVar)
      else: newLit("")))

  result = newBlockStmt(stmtlist)

macro dbgAssert*(condition: untyped, params:varargs[typed]) : untyped =
  ## Assert macro that prints the names and contents of variables if the
  ## given condition is not true
  var stmtList = newNimNode(nnkStmtList)
  var subStmt = newNimNode(nnkStmtList)
  #[ build statement:
    if not expr:  
      failedAssertImpl(...) <- subStmt
  ]#
  stmtList.
    add(newNimNode(nnkIfStmt).
      add(newNimNode(nnkElifBranch).
        add(prefix(condition, "not")).add(subStmt)))

  let strRepr = mkDbgStr(params)
  let failedCond = newCall(ident("astToStr"), condition)
  subStmt.
    add(strRepr).
    add(newCall(ident("failedAssertImpl"),
      if len(strRepr) > 0: 
        infix(failedCond, "&", 
          infix(newLit(" - "), "&", ident(tmpVar)))
      else:
        failedCond
    ))
  result = newBlockStmt(stmtlist)


when isMainModule:
  ## Example use
  var x = 22; var y = 33
  dbgEcho("Test output",x,y)
  # prints 'Test ouput x=22, y=33'
  dbgEcho("Single Output")
  # prints 'Single Output'
  let s = dbgString(y,x)
  echo(s)
  # prints y=33, x=22 
  dbgAssert(x == y, "x and y should be equal", x,y)
  # raises an assertion and prints 'x == y - x and y should be equal x:22, y:33'

