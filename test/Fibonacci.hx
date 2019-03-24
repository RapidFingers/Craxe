class Fibonacci {
	static function fib(n:Int) {
		if (n <= 2) {
			return 1;
		}

		return fib(n - 1) + fib(n - 2);
	}

	public static function main() {
		trace(fib(50));
	}
}
