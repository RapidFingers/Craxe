{.experimental: "codeReordering".}

proc incRet[T](val:var T):T {.discardable, inline.} =
    inc(val)
    val

type 
    HundredDoors = ref object of RootObj
    HundredDoorsStatic = ref object of RootObj

let HundredDoorsStaticInst = HundredDoorsStatic()

proc main(this : HundredDoorsStatic) : void =
    HundredDoorsStaticInst.findOpenLockers(100)

proc findOpenLockers(this : HundredDoorsStatic, n : int) : void =
    var i = 1
    while i * i <= n:
        echo(i * i)
        incRet(i)

HundredDoorsStaticInst.main()