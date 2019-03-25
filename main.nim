{.experimental: "codeReordering".}

proc incRet[T](val:var T):T {.discardable, inline.} =
    inc(val)
    val

type 
    ArrayTest = ref object of RootObj
    ArrayTestStatic = ref object of RootObj

let ArrayTestStaticInst = ArrayTestStatic()

proc main(this : ArrayTestStatic) : void =
    var arr = Array()
    arr.push(33)
    arr.push(44)
    arr.push(55)
    echo(arr)

ArrayTestStaticInst.main()