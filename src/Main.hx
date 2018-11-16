class Printer {
    public var name:String;

    public function new() {}    

    public function print(v1:Int, v2:Int) {
        var d = v1 + v2;
        name = Std.string(d);
    }

    public static function test() {
        trace("GOOD");
    }
}

class Main {
    public static function main() {
        var printer = new Printer();
        printer.print(101, 44);
        trace(printer.name);
        Printer.test();
    }
}