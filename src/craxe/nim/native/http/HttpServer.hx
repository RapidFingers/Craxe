package craxe.nim.native.http;

import craxe.nim.native.async.Future;
import craxe.nim.native.async.AsyncDispatch.Port;

/**
 * Http code type
 */
@:require("asynchttpserver")
extern class HttpCode extends Distinct<Int> {}

/**
 * Extern for http request
 */
@:require("asynchttpserver")
extern class Request {
    public function respond(code: HttpCode, content: String):Future<Void>;
}

/**
 * Extern for asynchttpserver
 */
@:require("asynchttpserver")
extern class AsyncHttpServer {
	/**
	 * Create new AsyncHttpServer	 
	 */
    @:topFunction
	@:native("newAsyncHttpServer")
	public static function create():AsyncHttpServer;

    /**
     * Start server
     */
    public function serve(port:Port, call:(Request)->Future<Void>):Future<Void>;
}