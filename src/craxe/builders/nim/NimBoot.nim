proc apOperator[T](val:var T):T {.discardable, inline.} =        
    result = val
    inc(val)

proc bpOperator[T](val:var T):T {.discardable, inline.} =        
    inc(val)
    result = val

template `+`(s:string, i:untyped): string =
    s & $i

template `+`(i:untyped, s:string): string =
    $i & s

template `+`(s1:string, s2:string): string =
    s1 & s2

type
    HaxeEnum = object of RootObj
        tag:string
        index:int

    HaxeArray[T] = ref object of RootObj
        data : seq[T]

proc newHaxeArray[T]() : HaxeArray[T] =
    result = HaxeArray[T]()

template push[T](this:HaxeArray[T], value:T) =
    this.data.add(value)

template pop[T](this:HaxeArray[T]): T =
    let last = this.data.len - 1
    let res = this.data[last]
    delete(this.data, last)
    res

template get[T](this:HaxeArray[T], pos:int): T =
    this.data[pos]

template length[T](this:HaxeArray[T]): int =    
    this.data.len

proc `$`[T](this:HaxeArray[T]) : string {.inline.} =
    result = $this.data