import tables
import core

const TABLE_INIT_SIZE = 33554432

type   
    # Base map
    HaxeMap*[K, V] = ref object of HaxeObject
        data*:Table[K, V]

    # Haxe String map
    HaxeStringMap*[T] = HaxeMap[string, T]

    # Haxe Int map
    HaxeIntMap*[T] = HaxeMap[int, T]

    # Haxe object map
    HaxeObjectMap*[K, V] = HaxeMap[K, V]

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