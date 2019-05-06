package craxe.nim.async;

/**
 * Future
 */
@:forward
abstract Future<T>(FutureImpl<T>) from FutureImpl<T> to FutureImpl<T> {
	/**
	 * Constructor	 
	 */
	public function new(v:FutureImpl<T>) {
		this = v;
	}
}

/**
 * Extern for future
 */
@:require("asyncdispatch")
@:native("Future")
extern class FutureImpl<T> {
	@:native("newFuture")
	public function new();

	/**
	 * Add callback for future
	 */
	public function addCallback(call:FutureImpl<T>->Void):Void;

	/**
	 * Get future result
	 */
	public function read():T;
}
