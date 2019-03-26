class MyType {
	public var id:Int;
	public var name:String;

	public function new(id:Int, name:String) {
		this.id = id;
		this.name = name;
	}
}

class ArrayTest {
	public static function main() {
		var arr = new Array<MyType>();
		arr.push(new MyType(1, "Batman"));
		// // arr.push(new MyType(2, "Superman"));

		//trace(arr);
	}
}
