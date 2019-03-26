class MyType {
    public final name:String;

    public function new(name:String) {
        this.name = name;
    }
}

class ArrayTest {	
	public static function main() {
		var arr = new Array<MyType>();
        arr.push(new MyType("Batman"));
        arr.push(new MyType("Superman"));

        trace(arr);
	}
}