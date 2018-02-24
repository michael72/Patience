import random
import times

proc splitmix(): uint64 =  
  var x {.global.} : uint64 = uint64(epochTime()*1000)
  var z: uint64 = x + 0x9E3779B97F4A7C15'u64
  z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9'u64
  z = (z xor (z shr 27)) * 0x94D049BB133111EB'u64
  x = z xor (z shr 31)
  result = x
  

proc rand*(maxInt: int): int =
  var initialized {.global.} = false
  if not initialized:
    initialized = true
    randomize(int(splitmix()))

  random.rand(maxInt)
