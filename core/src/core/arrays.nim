import tables
import core

type
    # Haxe array
    HaxeArray*[T] = ref object of HaxeObject
        data*:seq[T]

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

template length*[T](this:HaxeArray[T]): int =    
    this.data.len

template `$`*[T](this:HaxeArray[T]) : string =
    $this.data