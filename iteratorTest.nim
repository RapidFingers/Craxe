type HaxeIterator[T] = ref object of RootObj
    iter:iterator():T
    value:T

proc next[T](this:HaxeIterator[T]):T =    
    result = this.value

proc hasNext[T](this:HaxeIterator[T]):bool =        
    this.value = this.iter()
    result = not finished(this.iter)

iterator myiterator(start:int, count:int):int =
    for i in start..<start + count:
        yield i

proc getmyiterator(start:int, count:int) : auto =
    return iterator(): int =
        for it in myiterator(start, count):
            yield it      

proc main() =
    var it = getmyiterator(10, 20)
    var iter = HaxeIterator[int](iter: it)
    while iter.hasNext():
        echo iter.next()

main()