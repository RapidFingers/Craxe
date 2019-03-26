package craxe.ast2obj;

class OClass {
	/**
	 * Super class
	 */
	public var superClass:OClass;
	/**
	 * Parameters for generics
	 */
	public var params:Array<String>;

	/**
	 * Class full name
	 */
	public var fullName:String = "";

	/**
	 * Is extern class
	 */
	public var isExtern:Bool = false;
	public var stackOnly:Bool = false;
	public var externName:String = null;
	public var externIncludes:Array<String> = null;
	public var methods:Array<OMethod> = [];
	public var classVars:Array<OClassVar> = [];

	public function new() {}

	public var safeName(get, null):String;

	private function get_safeName():String {
		return StringTools.replace(fullName, ".", "_");
	}
}
