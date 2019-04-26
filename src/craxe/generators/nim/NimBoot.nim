import tables

type
    StdStatic* = object
    LogStatic* = object
    HaxeBytesStatic* = object
    FileStatic* = object

    # Objects that can calculate self hash
    Hashable = concept x
        x.hash is proc():int

    # Main object for all haxe objects
    HaxeObject* = RootObj

    # Main object for all haxe referrence objects
    HaxeObjectRef* = ref HaxeObject

    # Value object
    Struct* = object of HaxeObject

    # Haxe enum
    HaxeEnum* = ref object of HaxeObject
        index*:int

    # Haxe array
    HaxeArray*[T] = ref object of HaxeObject
        data*:seq[T]

    HaxeMap*[K, V] = ref object of HaxeObject
        data*:Table[K, V]

    # Haxe String map
    HaxeStringMap*[T] = HaxeMap[string, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int, T]

    # Haxe object map
    HaxeObjectMap*[K, V] = HaxeMap[K, V]
    
    # Haxe bytes
    HaxeBytes* = ref object of HaxeObject
        b*:seq[byte]
    
        
    ValueType = int | string | float | object

    Null*[ValueType] = object
        case has*:bool
        of true:
            value*:ValueType
        of false:
            discard 

    # Dynamic
    DynamicType* = enum
        TString, TInt, TFloat, TClass, TPointer

    Dynamic* = ref object
        case kind: DynamicType
        of TString: fstring:string
        of TInt: fint:int
        of TFloat: ffloat:float
        of TClass: 
            fclass: HaxeObjectRef
            fields:Table[string, Dynamic]
        of TPointer: fpointer: pointer

let LogStaticInst* = LogStatic()
let StdStaticInst* = StdStatic()
let HaxeBytesStaticInst* = HaxeBytesStatic()
let FileStaticInst* = FileStatic()

# Sys procedures
proc apOperator*[T](val:var T):T {.discardable, inline.} =        
    result = val
    inc(val)

proc bpOperator*[T](val:var T):T {.discardable, inline.} =        
    inc(val)
    result = val

template `+`*(s:string, i:untyped): string =
    s & $i

template `+`*(i:untyped, s:string): string =
    $i & s

template `+`*(s1:string, s2:string): string =
    s1 & s2

template toString*(this:untyped):untyped =
    $this

template hash*(this:Hashable):int =
    this.hash()

proc `==`*(v1:Null[ValueType], v2:ValueType):bool =
    if v1.has:
        return v1.value == v2
    return false

converter toValue*[ValueType](value:Null[ValueType]):ValueType =
    if value.has:
        return value.value
    raise newException(NilAccessError, "Null pointer exception")

proc `$`*(this:Null[ValueType]):string =
    if this.has:
        return $this.value
    return "nil"

proc `==`*[T](v1:Null[T], v2:Null[T]):bool =
    if v1.has and v2.has:
        return v1.value == v2.value    
    return false

proc `==`*(v1:Hashable, v2:Hashable):bool =
    v1.hash() == v2.hash()

template hash*(this:HaxeObjectRef):int =
    cast[int](this)

proc `==`*(v1:HaxeObjectRef, v2:HaxeObjectRef):bool =
    v1.hash() == v2.hash()

# Log
template trace*(this:LogStatic, v:byte, e:varargs[string, `$`]):void =
    write(stdout, e[0] & " " & e[1] & ": ")
    echo cast[int](v)

template trace*(this:LogStatic, v:untyped, e:varargs[string, `$`]):void =
    write(stdout, e[0] & " " & e[1] & ": ")
    echo v

# String
template length*(this:string) : int =
    len(this)

# String
template charAt*(this:string, pos:int) : string =
    $this[pos]

# Enum
proc `$`*(this:HaxeEnum) : string =
    result = $this[]

proc `==`*(e1:HaxeEnum, e2:int) : bool {.inline.} =
    result = e1.index == e2

# HaxeArray
proc newHaxeArray*[T]() : HaxeArray[T] =
    result = HaxeArray[T]()

proc `[]`*[T](this:HaxeArray[T], pos:int):T =
    this.data[pos]

template push*[T](this:HaxeArray[T], value:T):int =
    this.data.add(value)
    len(this.data)

template pop*[T](this:HaxeArray[T]): T =
    let last = this.data.len - 1
    let res = this.data[last]
    delete(this.data, last)
    res

template get*[T](this:HaxeArray[T], pos:int): T =
    this.data[pos]

template length*[T](this:HaxeArray[T]): int =    
    this.data.len

template `$`*[T](this:HaxeArray[T]) : string =
    $this.data

# Haxe Map
template set*[K, V](this:HaxeMap[K, V], key:K, value:V) =
    this.data[key] = value

proc get*[K](this:HaxeMap[K, ValueType], key:K):Null[ValueType] =    
    if this.data.hasKey(key):
        return Null[ValueType](has: true, value: this.data[key])
    else:
        return Null[ValueType](has: false)

template get*[K, V](this:HaxeMap[K, V], key:K):V =
    if this.data.hasKey(key):
        this.data[key]
    else:
        nil

template `$`*[K, V](this:HaxeMap[K, V]) : string =
    $this.data

proc newStringMap*[T]() : HaxeStringMap[T] =
    result = HaxeStringMap[T]()
    result.data = initTable[string, T]()

proc newIntMap*[T]() : HaxeIntMap[T] =
    result = HaxeIntMap[T]()
    result.data = initTable[int, T]()

proc newObjectMap*[K, V]() : HaxeObjectMap[K, V] =
    result = HaxeObjectMap[K, V]()
    result.data = initTable[K, V]()

# Bytes
template alloc*(this:HaxeBytesStatic, size:int) : HaxeBytes =
    HaxeBytes(b: newSeq[byte](size));    

template get*(this:seq[byte], pos:int):Natural =
    this[pos]

template get*(this:HaxeBytes, pos:int):Natural =
    this.b[pos]

template set*(this:var seq[byte], pos:int, v:Natural) =
    this[pos] = v.byte

template set*(this:HaxeBytes, pos:int, v:Natural) =
    this.b.set(pos, v)

template length*(this:HaxeBytes): int =    
    len(this.b)

template `[]`*(this:HaxeBytes, pos:int): Natural =    
    this.b[pos]

template `[]=`*(this:HaxeBytes, pos:int, value:int) =    
    this.b[pos] = value.byte

# File
template getContent*(this:FileStatic, path:string): string =
    readFile(path)

# Dynamic 
proc `$`*(this:Dynamic):string =
    case this.kind
    of TString:
        return this.fstring
    of TInt:
        return $this.fint
    of TFloat:
        return $this.ffloat
    of TClass:
        return $this.fclass[]
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

proc newDynamic*(value:HaxeObjectRef):Dynamic =    
    return Dynamic(kind:TClass, fclass: value)

proc newDynamic*(value:pointer):Dynamic =    
    return Dynamic(kind:TPointer, fpointer: value)

proc setField*(this:Dynamic, name:string, value:string) =
    this.fields[name] = Dynamic(kind: TString, fstring: value)

proc setField*(this:Dynamic, name:string, value:int) =
    this.fields[name] = Dynamic(kind: TInt, fint: value)

proc setField*(this:Dynamic, name:string, value:float) =
    this.fields[name] = Dynamic(kind: TFloat, ffloat: value)

proc setField*(this:Dynamic, name:string, value:HaxeObjectRef) =
    this.fields[name] = Dynamic(kind: TClass, fclass: value)

proc setField*(this:Dynamic, name:string, value:pointer) =
    this.fields[name] = Dynamic(kind: TPointer, fpointer: value)

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

converter fromString*(value:string):Dynamic =
    newDynamic(value)

converter fromInt*(value:int):Dynamic =
    newDynamic(value)

converter fromFloat*(value:float):Dynamic =
    newDynamic(value)

proc call*(this:Dynamic, name:string, args:varargs[Dynamic]): Dynamic =
    nil