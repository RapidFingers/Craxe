package craxe.nim.http;

import craxe.nim.async.Future;
import craxe.nim.async.Async;
import craxe.nim.http.HttpCommon;
import craxe.nim.util.Url;

/**
 * Http request
 */
extern class HttpRequest {
	/**
	 * Http method
	 */
	public var httpMethod:HttpMethod;

	/**
	 * Url of request
	 */
	public var url:Url;

	/**
	 * Send data with 200 OK code
	 */
	public function sendOk(content:String):Void;	
}

/**
 * Async http server
 */
extern class HttpServer {
	/**
	 * Constructor
	 */
	@:native("newHttpServer")
	public function new(port:Int, address:String = "");

	/**
	 * Run server
	 */
	public function run(call:(HttpRequest) -> Async<Void>):Future<Void>;
}
