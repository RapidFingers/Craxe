import tables
import core

type
    # Haxe anonimous object
    AnonObject* = ref object of HaxeObject
        names*: seq[string]
        values*: seq[Dynamic]

    # Dynamic
    DynamicType* = enum
        TString, TInt, TFloat, TAnonObject

    Dynamic* = ref object
        case kind*: DynamicType
        of TString: fstring*:string
        of TInt: fint*:int
        of TFloat: ffloat*:float
        of TAnonObject: fanon*: AnonObject

# AnonObject
proc newAnonObject*(names: seq[string]) : AnonObject =
    AnonObject(
        names: names,
        values: newSeqOfCap[Dynamic](names.len)
    )

template setField*[T](this:AnonObject, pos:int, value:T) =
    this.values[pos] = value

template getField*[T](this:AnonObject, pos:int, tp:typedesc[T]):T =
    this.values[pos]

template getFields*(this:AnonObject):seq[string] =
    this.names

# Dynamic 
proc `$`*(this:Dynamic):string =
    case this.kind
    of TString:
        return this.fstring
    of TInt:
        return $this.fint
    of TFloat:
        return $this.ffloat
    of TAnonObject:
        return $this[]
    else:
        return "Dynamic unknown"

template newDynamic*(value:string):Dynamic =
    Dynamic(kind:TString, fstring: value)

template newDynamic*(value:int):Dynamic =
    Dynamic(kind:TInt, fint: value)

template newDynamic*(value:float):Dynamic =
    Dynamic(kind:TFloat, ffloat: value)

template newDynamic*(value:AnonObject):Dynamic =
    Dynamic(kind:TAnonObject, fanon: value)

converter toInt*(this:Dynamic):int =
    case this.kind
    of TInt:
        return this.fint
    else:
        raise newException(ValueError, "Dynamic wrong type")

converter toFloat*(this:Dynamic):float =
    case this.kind
    of TFloat:
        return this.ffloat
    else:
        raise newException(ValueError, "Dynamic wrong type")
    
converter toString*(this:Dynamic):string =
    case this.kind
    of TString:
        return this.fstring
    else:
        raise newException(ValueError, "Dynamic wrong type")

converter fromString*(value:string):Dynamic =
    newDynamic(value)

converter fromInt*(value:int):Dynamic =
    newDynamic(value)

converter fromFloat*(value:float):Dynamic =
    newDynamic(value)

converter fromAnon*(value:AnonObject):Dynamic =
    newDynamic(value)