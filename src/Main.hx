class Printer {
    public var name:String;

    public function new() {}    

    public function print(v1:Int, v2:Int) {
        var d = v1 + v2;
        name = Std.string(d);
    }
}

class Main {
    public static function main() {
        var printer = new Printer();
        printer.print(44, 22);
        trace(printer.name);
    }
}