package craxe.nim.native.async;

/**
 * Port type
 */
@:require("asyncdispatch")
extern class Port extends Distinct<Int> {}

/**
 * Extern for asyncdispatch
 */
@:require("asyncdispatch")
extern class AsyncDispatch {
	/**
	 * Start event loop
	 */
	@:topFunction
	public static function runForever():Void;
}
