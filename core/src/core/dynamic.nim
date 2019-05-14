import tables
import core

type
    # Dynamic
    DynamicType* = enum
        TString, TInt, TFloat, TObject, TPointer

    Dynamic* = ref object
        case kind*: DynamicType
        of TString: fstring:string
        of TInt: fint:int
        of TFloat: ffloat:float
        of TObject:
            fields*: Table[string, Dynamic]
        of TPointer: fpointer: pointer

# Dynamic 
proc `$`*(this:Dynamic):string =
    case this.kind
    of TString:
        return this.fstring
    of TInt:
        return $this.fint
    of TFloat:
        return $this.ffloat
    of TObject:
        return $this.fields
    of TPointer:
        return "Pointer"
    else:
        return "Dynamic unknown"

proc newDynamic*(value:string):Dynamic =    
    return Dynamic(kind:TString, fstring: value)

proc newDynamic*(value:int):Dynamic =    
    return Dynamic(kind:TInt, fint: value)

proc newDynamic*(value:float):Dynamic =    
    return Dynamic(kind:TFloat, ffloat: value)

proc newDynamicObject*():Dynamic =    
    var res = Dynamic(kind:TObject)
    res.fields = initTable[string, Dynamic]()
    return res

proc newDynamic*(value:pointer):Dynamic =    
    return Dynamic(kind:TPointer, fpointer: value)

proc getFields*(this:Dynamic):Table[string, Dynamic] =
    case this.kind
    of TObject:
        return this.fields
    else:
        raise newException(ValueError, "Dynamic wrong type")

proc setField*(this:Dynamic, name:string, value:string) =
    this.fields[name] = Dynamic(kind: TString, fstring: value)

proc setField*(this:Dynamic, name:string, value:int) =
    this.fields[name] = Dynamic(kind: TInt, fint: value)

proc setField*(this:Dynamic, name:string, value:float) =
    this.fields[name] = Dynamic(kind: TFloat, ffloat: value)

proc setField*(this:Dynamic, name:string, value:Dynamic) =
    this.fields[name] = value

proc setField*(this:Dynamic, name:string, value:pointer) =
    this.fields[name] = Dynamic(kind: TPointer, fpointer: value)

proc getFieldValue*(this:Dynamic, name:string):Dynamic =
    case this.kind
    of TObject:
        return this.fields[name]
    else:
        raise newException(ValueError, "Dynamic wrong type")

proc getIntField*(this:Dynamic, name:string):int =
    let fld = this.fields[name]
    return fld.fint

proc getStringField*(this:Dynamic, name:string):string =
    let fld = this.fields[name]
    return fld.fstring

proc getClassField*[T](this:Dynamic, name:string, tp:typedesc[T]):T =
    let fld = this.fields[name]
    return cast[T](fld.fref)

proc getPointerField*[T](this:Dynamic, name:string, tp:typedesc[T]):T =
    let fld = this.fields[name]
    return cast[T](fld.fpointer)

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

proc call*(this:Dynamic, name:string, args:varargs[Dynamic]): Dynamic =
    nil