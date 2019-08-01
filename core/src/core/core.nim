{.experimental: "codeReordering".}

import tables

type
    # Objects that can calculate self hash
    Hashable = concept x
       x.hash is proc():int

    # Main object for all haxe objects
    # All classes without reflection
    HaxeObject* = RootObj

    # Reference to HaxeObject
    HaxeObjectRef* = ref HaxeObject

    # Interface object
    # Container for HaxeObject with links for it fields
    InterfaceHaxeObject* = object of HaxeObject
        obj*: HaxeObjectRef

    # Reference to InterfaceHaxeObject
    InterfaceHaxeObjectRef* = ref InterfaceHaxeObject

    # Object with introspection but no possibility to add/remove fields
    # Classes with reflection, or using as AnyType
    IntrospectiveHaxeObject* = object of HaxeObject
        # Return names of object fields
        getFields*:proc():HaxeArray[string] {.gcsafe.}
        # Return field value as AnyType by name
        getFieldByName*:proc(name:string):AnyType {.gcsafe.}
        # Set field value by name
        setFieldByName*:proc(name:string, value:AnyType):void {.gcsafe.}

    # Reference to IntrospectiveHaxeObject    
    IntrospectiveHaxeObjectRef* = ref IntrospectiveHaxeObject

    # Mutable object with all reflection possibility
    # Anonimous object (typedef)
    ReflectiveHaxeObject* = object of IntrospectiveHaxeObject
        # Fields for add/delete by reflection
        fields: HaxeStringMap[AnyType]

    ReflectiveHaxeObjectRef* = ref ReflectiveHaxeObject

    # Value object
    Struct* = object of HaxeObject

    ValueType* = int | string | float | object

    Null*[ValueType] = object
        case has*:bool
        of true:
            value*:ValueType
        of false:
            discard

    # --- Haxe Iterator ---

    HaxeIterator*[T] = ref object of InterfaceHaxeObject
        hasNext*:proc():bool
        next*:proc():T

    # --- Haxe Array ---    

    HaxeArrayIterator*[T] = ref object of HaxeIterator[T]
        arr:HaxeArray[T]
        currentPos:int

    HaxeArray*[T] = ref object of HaxeObject
        data*:seq[T]

    # --- Haxe Map

    # Base map
    HaxeMap*[K, V] = ref object of HaxeObject
        data*:Table[K, V]

    # Haxe String map
    HaxeStringMap*[T] = HaxeMap[string, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int, T]

    # Haxe object map
    HaxeObjectMap*[K, V] = HaxeMap[K, V]

    # --- Any ---
    
    # Field of object that can be added or deleted
    AnyTypeField* = ref object
        name*:string        
        value*:AnyType    

    # AnyType types
    AnyTypeEnum* = enum
        TString, TInt, TFloat, TIntrospectiveObject, TReflectiveObject, TProc

    AnyType* = ref object of HaxeObject
        case kind*: AnyTypeEnum
        of TString: 
            fstring*:string
        of TInt: 
            fint*:int
        of TFloat: 
            ffloat*:float
        of TIntrospectiveObject:
            fobjectIntro*: IntrospectiveHaxeObjectRef
        of TReflectiveObject:
            fobjectRefl*: ReflectiveHaxeObjectRef
        of TProc:
            fproc*: pointer

    # --- Haxe Enum ---

    # Haxe enum
    HaxeEnum* = ref object of HaxeObject
        index*:int

template newAnyType*(value:string):AnyType =
    AnyType(kind:TString, fstring: value)

template newAnyType*(value:int):AnyType =
    AnyType(kind:TInt, fint: value)

template newAnyType*(value:float):AnyType =
    AnyType(kind:TFloat, ffloat: value)

template newAnyType*(value:IntrospectiveHaxeObjectRef):AnyType =
    AnyType(kind:TIntrospectiveObject, fobjectIntro: value)

template newAnyType*(value:ReflectiveHaxeObjectRef):AnyType =
    AnyType(kind:TReflectiveObject, fobjectRefl: value)

proc newAnyType*(value:proc):AnyType =
    AnyType(kind:TProc, fproc: cast[pointer](value))

template toAnyType*(this:untyped):untyped =
    newAnyType(this)

# Core procedures
# a++
proc apOperator*[T](val:var T):T {.discardable, inline.} =        
    result = val
    inc(val)

# ++a
proc bpOperator*[T](val:var T):T {.discardable, inline.} =        
    inc(val)
    result = val

template `+`*(s:string, i:untyped): string =
    s & $i

template `+`*(i:untyped, s:string): string =
    $i & s

template `+`*(s1:string, s2:string): string =
    s1 & s2

template toString*(this:untyped):string =
    $this

# String
template length*(this:string) : int =
    len(this)

# String
template charAt*(this:string, pos:int) : string =
    $this[pos]

proc `==`*(v1:Null[ValueType], v2:ValueType):bool =
    if v1.has:
        return v1.value == v2
    return false

proc `$`*(this:Null[ValueType]):string =
    if this.has:
        return $this.value
    return "nil"

proc `==`*(v1:Hashable, v2:Hashable):bool =
    v1.hash() == v2.hash()

template hash*(this:HaxeObjectRef):int =
    cast[int](this)

proc `==`*(v1:HaxeObjectRef, v2:HaxeObjectRef):bool =
    v1.hash() == v2.hash()

proc `==`*[T](v1:Null[T], v2:Null[T]):bool =
    if v1.has and v2.has:
        return v1.value == v2.value    
    return false

# Scoped block
template valueBlock*(body : untyped) : untyped = 
    (proc() : auto {.gcsafe.} = 
        body
    )()

# --- Haxe Array ---

# HaxeArray
proc newHaxeArray*[T]() : HaxeArray[T] =
    result = HaxeArray[T]()

proc newHaxeArray*[T](data:seq[T]) : HaxeArray[T] =
    result = HaxeArray[T](data: data)

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

# Removes the first occurrence of v in this Array 
template remove*[T](this:HaxeArray[T], v:T) : bool =
    let id = this.data.find(v)
    if id > -1:
        this.data.del(id)

template length*[T](this:HaxeArray[T]): int =    
    this.data.len

template `$`*[T](this:HaxeArray[T]) : string =
    $this.data

proc newHaxeArrayIterator*[T](arr:HaxeArray[T]) : HaxeArrayIterator[T] =
    var res = HaxeArrayIterator[T](arr: arr)
    res.hasNext = proc():bool =
        return res.currentPos < length(res.arr)
    res.next = proc():T =
        result = res.arr[res.currentPos]
        inc(res.currentPos)

    return res

proc `iterator`*[T](this:HaxeArray[T]):HaxeIterator[T] =
    return newHaxeArrayIterator(this)

# --- Haxe Map --- 

const TABLE_INIT_SIZE = 64

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
    result.data = initTable[string, T](TABLE_INIT_SIZE)

proc newIntMap*[T]() : HaxeIntMap[T] =
    result = HaxeIntMap[T]()
    result.data = initTable[int, T](TABLE_INIT_SIZE)

proc newObjectMap*[K, V]() : HaxeObjectMap[K, V] =
    result = HaxeObjectMap[K, V]()
    result.data = initTable[K, V](TABLE_INIT_SIZE)

# --- AnyType ---

# ReflectiveHaxeObjectRef  

# Create new reflective object only with anonimous fields
proc newAnonReflectiveObject*() : ReflectiveHaxeObjectRef =
    var this = ReflectiveHaxeObjectRef()
    this.fields = newStringMap[AnyType]()
    this.getFieldByName = proc(name:string):AnyType =
        getAnonFieldByName(this, name)

    this.setFieldByName = proc(name:string, value:AnyType):void =
        setAnonFieldByName(this, name, value)
    
    this.getFields = proc():HaxeArray[string] =
        var fields = newSeq[string]()
        for it in this.fields.data.keys():
            fields.add(it)

        return newHaxeArray[string](fields)

    return this
    
proc setAnonFieldByName*(this:ReflectiveHaxeObjectRef, name:string, value:AnyType) {.inline.} =    
    this.fields.set(name, value)

proc getAnonFieldByName*(this:ReflectiveHaxeObjectRef, name:string):AnyType {.inline.} =
    return this.fields.get(name)

proc deleteField*(this:ReflectiveHaxeObjectRef, name:string):void {.inline.} =    
    #this.fields.delete(name)
    discard

# AnyType 

proc `$`*(this:AnyType):string =
    if this.isNil:
        return "null"
    case this.kind
    of TString:
        return this.fstring
    of TInt:
        return $this.fint
    of TFloat:
        return $this.ffloat
    of TIntrospectiveObject:
        let fields = this.fobjectIntro.getFields()
        var data = newSeq[string]()
        for fld in fields.data:
            var val = this.fobjectIntro.getFieldByName(fld)
            if not val.isNil:
                data.add(fld & ": " & $val)
        return $data
    of TReflectiveObject:
        let fields = this.fobjectRefl.getFields()
        var data = newSeq[string]()
        for fld in fields.data:
            var val = this.fobjectRefl.getFieldByName(fld)
            if not val.isNil:
                data.add(fld & ": " & $val)
        return $data
    of TProc:
        return "Proc"

proc `$`*(this:AnyTypeField):string =
    return $this.value

proc getField*(this:AnyType, name:string):AnyType {.gcsafe.} =
    case this.kind    
    of TIntrospectiveObject:
        this.fobjectIntro.getFieldByName(name)
    of TReflectiveObject:
        this.fobjectRefl.getFieldByName(name)
    else:
        nil

proc getFields*(this:AnyType):HaxeArray[string] {.gcsafe.} =    
    case this.kind
    of TIntrospectiveObject:
        this.fobjectIntro.getFields()
    of TReflectiveObject:
        this.fobjectRefl.getFields()
    else:
        nil

proc getObject*(this:AnyType):HaxeObjectRef =
    case this.kind
    of TIntrospectiveObject:
        this.fobjectIntro
    of TReflectiveObject:
        this.fobjectRefl
    else:
        nil

template call*[T](this:AnyType, tp:typedesc[T]):untyped =
    case this.kind
    of TProc:
        var pr:T = cast[tp](this.fproc)
        pr()
    else:
        raise newException(ValueError, "AnyType wrong type")

template call*[T](this:AnyType, tp:typedesc[T], args:untyped):untyped =
    case this.kind
    of TProc:
        var pr:T = cast[tp](this.fproc)
        pr(args)
    else:
        raise newException(ValueError, "AnyType wrong type")

template call*[T](this:AnyType, name:string, tp:typedesc[T], args:untyped):untyped =    
    case this.kind:
    of TAnonObject, TObject:
        this.getField(name).call(tp, args)
    else:
        raise newException(ValueError, "AnyType wrong type")

# --- Haxe Enum ---

# Enum
proc `$`*(this:HaxeEnum) : string =
    result = $this[]

proc `==`*(e1:HaxeEnum, e2:int) : bool {.inline.} =
    result = e1.index == e2