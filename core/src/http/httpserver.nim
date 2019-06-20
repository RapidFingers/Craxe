import asyncdispatch, asynchttpserver, uri

type
    HttpRequest* = ref object
        request: Request
        httpMethod*: HttpMethod
        url*:Uri

    HttpResponse* = ref object
        request: Request
        contentType*: string
        code*: HttpCode

    HttpServer* = ref object
        server:AsyncHttpServer
        port:Port
        address:string

    RequestHandler* = proc(req:HttpRequest, resp:HttpResponse):Future[void] {.gcsafe.}

# Send data
proc send*(this:HttpResponse, content:string) =
    var headers = newHttpHeaders([("Content-Type", this.contentType)])
    asyncCheck this.request.respond(HttpCode(this.code), content, headers)

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
                ),
                HttpResponse(
                    request: req,
                    contentType: "text/plain",
                    code: Http200
                )
            )
    )