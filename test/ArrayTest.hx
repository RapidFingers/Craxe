class MyType {
    public function new() {}
}

class ArrayTest {	
	public static function main() {
		var arr = new Array<MyType>();
        arr.push(new MyType());
        arr.push(new MyType());
        arr.push(new MyType());
        trace(arr);
	}
}