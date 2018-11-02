class Main {
    public var name:String;

    public function new() {
    }

    public function test() {
        var d = 33;
        name = Std.string(d);
        return name;
    }

    public static function main() {
        var m = new Main();
        m.name = "GOOD";
        trace(m.test());
    }
}