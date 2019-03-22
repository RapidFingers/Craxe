template incRet(val:var untyped):untyped =
    inc(val)
    val

type 
    Main = ref object of RootObj
    MainStatic = ref object of RootObj

let MainStaticInst = MainStatic()

proc fib(this : MainStatic, n : int) : int =
    if n <= 2:
        return 1
    return MainStaticInst.fib(n - 1) + MainStaticInst.fib(n - 2)

proc main(this : MainStatic) : void =
    echo(MainStaticInst.fib(50))

MainStaticInst.main()
