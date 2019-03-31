# Warning. Just an experiment. Lot of bugs!!!

## Transpiler from haxe to nim (http://nim-lang.org/) and maybe to crystal (http://crystal-lang.org/)

## What it can do:

* Classes: constructor, methods, instance fields
* Basic types: Int, Float, String, Bool and Array
* Enums and ADT
* Expressions: for, while, if
* Stdin output by trace

## How to use it

* Create project with "src" folder and Main.hx in it
* Add build.hxml with following strings:\
-cp src\
--macro craxe.Generator.generate()\
--no-output\
-lib craxe\
-main Main\
-D nim\
-D nim-out=main.nim\
* Add some simple code to Main.hx
* Launch "haxe build.hxml"
* Launch "nim c -d:release main.nim" and pray :)

## Examples

https://github.com/Grabli66/CraxeExamples

## Roadmap

- [ ] Switch expression
- [ ] Inheritance
- [ ] Interfaces
- [ ] Generics
- [ ] GADT
- [ ] Some kind of std lib
- [ ] Benchmarks
- [ ] Extern for nim asynchttp or httpbeast
- [ ] Example of async http server
