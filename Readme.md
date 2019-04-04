# Warning. Just an experiment. Lot of bugs!!!

## Transpiler from haxe to nim (http://nim-lang.org/)

## The main goal for now is:
* High performance.
* Low memory footprint.
* Stable garbage collector, or maybe no GC at all (is relevant to nim target).
* Async IO: Files, TCP, UDP, HTTP, HTTPS, Websockets.

## What it's all good for?

Backend, micro services, iot, calculations, haxe compiler :)

## Why not go, rust, D and other languages?

Because.

## What it can do:

* Classes: 
    - inheritance
    - constructors
    - super call
    - static and instance methods
    - instance fields
* Interfaces
* Basic types: 
    - Int
    - Float
    - String
    - Bool
    - Generic Array<T>
* Enums and ADT
* Expressions: 
    - for
    - while
    - if
    - switch
* Stdin output by trace

## How to use it

* Install craxe by "haxelib git craxe https://github.com/RapidFingers/Craxe"
* Create project with "src" folder and Main.hx in it
* Add build.hxml with following strings:\
-cp src\
--macro craxe.Generator.generate()\
--no-output\
-lib craxe\
-main Main\
-D nim\
-D nim-out=main.nim
* Add some simple code to Main.hx
* Launch "haxe build.hxml"
* Launch "nim c -d:release main.nim" and pray :)

## Examples

https://github.com/RapidFingers/CraxeExamples

## Roadmap for nim target

- [x] Switch expression
- [x] Inheritance
- [x] Interfaces
- [ ] Type checking (operator is)
- [ ] Map/Dictionary
- [ ] Generics
- [ ] GADT
- [ ] Abstracts
- [ ] Closures
- [ ] Externs
- [ ] Some kind of std lib
- [ ] Benchmarks
- [ ] Extern for nim asynchttp or httpbeast
- [ ] Example of async http server
