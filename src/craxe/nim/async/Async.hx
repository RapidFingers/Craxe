package craxe.nim.async;

/**
 * For {.async.} pragma
 */
extern abstract Async<T>(T) {
	@:from public static function from<T>(v:T):Async<T>;
}
