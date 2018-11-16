type 
    Printer = ref object of RootObj
        name : string
    PrinterStatic = ref object of RootObj
    Main = ref object of RootObj
    MainStatic = ref object of RootObj

let PrinterStaticInst = PrinterStatic()
let MainStaticInst = MainStatic()

proc print(this : Printer, v1 : int, v2 : int) : void =
    var d = v1 + v2
    this.name = $(d)

proc test(this : PrinterStatic) : void =
        echo("GOOD")

proc main(this : MainStatic) : void =
    var printer = Printer()
    printer.print(101, 44)
    echo(printer.name)
    PrinterStaticInst.test()


MainStaticInst.main()
