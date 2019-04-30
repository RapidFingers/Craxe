package craxe.nim.http;

import craxe.nim.async.Future;

/**
 * Http request
 */
extern class HttpRequest {
    /**
     * Send data with 200 OK code
     */
    public function sendOk(content:String):Future<Void>;
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
    public function run(call:(HttpRequest)->Future<Void>):Future<Void>;
}