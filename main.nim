template incRet(val:var untyped):untyped =
    inc(val)
    val

type 
    Fibonacci = ref object of RootObj
    FibonacciStatic = ref object of RootObj

let FibonacciStaticInst = FibonacciStatic()

proc fib(this : FibonacciStatic, n : int) : int =
    if n <= 2:
        return 1
    return FibonacciStaticInst.fib(n - 1) + FibonacciStaticInst.fib(n - 2)

proc main(this : FibonacciStatic) : void =
    echo(FibonacciStaticInst.fib(50))

FibonacciStaticInst.main()
