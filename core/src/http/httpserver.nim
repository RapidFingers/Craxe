import asyncdispatch, asynchttpserver, uri

type
    HttpRequest* = ref object
        request: Request
        httpMethod*: HttpMethod
        url*:Uri

    HttpServer* = ref object
        server:AsyncHttpServer
        port:Port
        address:string

    RequestHandler* = proc(req:HttpRequest):Future[void] {.gcsafe.}

# Send data
proc send*(this:HttpRequest, code:HttpCode, content:string) =
    asyncCheck this.request.respond(code, content)

# Send data with ok code
proc sendOk*(this:HttpRequest, content:string) =
    this.send(Http200, content)

# Create new http server
proc newHttpServer*(port = 8080, address = ""):HttpServer =
    result = HttpServer(port:Port(port), address:address)
    let server = newAsyncHttpServer()
    result.server = server

# Run server
proc run*(this:HttpServer, handler:RequestHandler) {.async.} =
    await this.server.serve(this.port, 
        proc(req:Request) {.async.} =
            await handler(
                HttpRequest(
                    request: req,
                    httpMethod: req.reqMethod,
                    url: req.url
                )
            )
    )