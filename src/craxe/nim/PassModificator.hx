package craxe.nim;

/**
 * Nim's "var" pass modificator to be possible modify value types
 */
@:forward
abstract Var<T>(T) {
	/**
	 * Constructor
	 */
	public function new(v:T) {
		this = v;
	}

	/**
	 * From any type	 
	 */
	@:from public static function fromAny<T>(v:T) {
		return new Var<T>(v);
	}

	/**
	 * Convert to any type
	 */
	@:to public function toAny<T>():T {
		return this;
	}
}