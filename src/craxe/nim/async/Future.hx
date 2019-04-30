package craxe.nim.async;

/**
 * Extern for future
 */
@:require("asyncdispatch")
extern class Future<T> {
	/**
	 * Add callback for future	 
	 */
	public function addCallback(call:Future<T>->Void):Void;

	/**
	 * Get future result
	 */
	public function read():T;
}