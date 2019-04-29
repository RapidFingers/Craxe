import asynchttpserver, asyncdispatch

import core/core

type
    HttpRequest* = ref object of HaxeObject
        httpMethod*: HttpMethod
        body*: string

    HttpServer* = ref object of HaxeObject        
        native: AsyncHttpServer
        port: int
        address: string

    RequestCallback* = proc(req:HttpRequest):Future[void]

proc newHttpServer*(port:int, address:string = ""):HttpServer =
    HttpServer(
        native: newAsyncHttpServer(true, true),
        port: port,
        address: address
    )

proc run*(this:HttpServer, call:RequestCallback) =
    asyncCheck this.native.serve(Port(this.port),
        proc(req:Request) {.async.} =
            await req.respond(Http200, "Hello World")
    )