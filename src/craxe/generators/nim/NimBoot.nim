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

type
    StdStatic* = object
    LogStatic* = object
    HaxeBytesStatic* = object
    FileStatic* = object

    Struct* = object of RootObj

    HaxeEnum* = ref object of RootObj
        index*:int

    HaxeArray*[T] = ref object of RootObj
        data*:seq[T]
    
    HaxeBytes* = ref object of RootObj
        b*:seq[byte]

let LogStaticInst* = LogStatic()
let StdStaticInst* = StdStatic()
let HaxeBytesStaticInst* = HaxeBytesStatic()
let FileStaticInst* = FileStatic()

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

template push*[T](this:HaxeArray[T], value:T) =
    this.data.add(value)

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