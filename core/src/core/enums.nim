import core

type
    # Haxe enum
    HaxeEnum* = ref object of HaxeObject
        index*:int

# Enum
proc `$`*(this:HaxeEnum) : string =
    result = $this[]

proc `==`*(e1:HaxeEnum, e2:int) : bool {.inline.} =
    result = e1.index == e2