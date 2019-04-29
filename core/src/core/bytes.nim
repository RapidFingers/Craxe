import core

type
    # Haxe bytes
    HaxeBytes* = ref object of HaxeObject
        b*:seq[byte]  

    HaxeBytesStatic = object

let HaxeBytesStaticInst* = HaxeBytesStatic()

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