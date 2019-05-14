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
}

/**
 * Extern to response
 */
extern class HttpResponse {
	/**
	 * Content type of response
	 * By default plain/text
	 */
	public var contentType:String;

	/**
	 * TODO HttpCode enum
	 * By default OK (200)
	 */
	public var code:Int;	

	/**
	 * Send data	 
	 */
	public function send(content:String):Void;
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
	public function run(call:(HttpRequest, HttpResponse) -> Async<Void>):Future<Void>;
}
