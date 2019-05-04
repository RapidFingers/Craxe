import asyncnet, asyncdispatch, strutils, parseutils, httpcore, tables

type
    HttpRequest* = ref object
        ctx:ClientCtx

    ClientCtx = ref object
        # Client socket
        socket:AsyncSocket
        # Client address
        address:string        
        # Request handler
        handler:RequestHandler
        # Http method
        httpMethod:HttpMethod
        # Resource
        resource:string
        # Version
        version:HttpVersion

        # Headers
        headers:Table[string, string]

    HttpServer* = ref object
        socket:AsyncSocket
        port:Port
        address:string

    HttpClient* = ref object

    RequestHandler* = proc(req:HttpRequest):Future[void] {.gcsafe.}

proc newClientCtx(client: AsyncSocket, address: string, handler:RequestHandler):ClientCtx =    
    result = ClientCtx(address: address, socket: client, handler: handler)

template checkEof(line:string) =
    if line.len < 1:
        raise newException(EOFError, "Disconnect")
    
proc readLine(this:ClientCtx):Future[string] {.async.} =
    var line = await this.socket.recvLine()
    checkEof(line)
    return line

template close(this:ClientCtx) =
    this.socket.close()

# Parse HTTP method
proc parseHttpMethod(name:string):HttpMethod =
    result =
        case name
        of "GET": HttpGet
        of "POST": HttpPost
        of "HEAD": HttpHead
        of "PUT": HttpPut
        of "DELETE": HttpDelete
        of "PATCH": HttpPatch
        of "OPTIONS": HttpOptions
        of "CONNECT": HttpConnect
        of "TRACE": HttpTrace
        else: raise newException(ValueError, "Invalid HTTP method " & name)

# Parse protocol version
proc parseProtocol(protocol: string): HttpVersion =
    var i = protocol.skipIgnoreCase("HTTP/")
    if i != 5:
        raise newException(ValueError, "Invalid request protocol. Got: " & protocol)
    let orig = protocol
    var major:int
    var minor:int
    i.inc protocol.parseSaturatedNatural(major, i)
    i.inc # Skip .
    i.inc protocol.parseSaturatedNatural(minor, i)

    if major == 1 and minor == 0:
        return HttpVer10

    if major == 1 and minor == 1:
        return HttpVer11

    raise newException(ValueError, "Unsupported protocol version")

# Read method, resource
proc readMethodAndUrl(this:ClientCtx):Future[void] {.async.} =
    var line = await this.readLine()    
    while line == "\c\L":
        line = await this.readLine()
    
    let items = line.split(' ')
    case items.len()
    of 1:
        this.httpMethod = parseHttpMethod(items[0])
    of 2:
        this.resource = items[1]
    of 3:
        this.version = parseProtocol(items[2])
    else:
        raise newException(ValueError, "Unsupported request")

# Read request type and headers data
proc readHeaders(this:ClientCtx):Future[void] {.async.} =
    var line = await this.readLine()
    this.headers = initTable[string, string]()
    while line != "\c\L":        
        let items = line.split(":")
        if items.len() == 2:
            this.headers[items[0]] = items[1]
        line = await this.readLine()

# Check if request has body
proc hasBody(this:ClientCtx):bool =
    return this.httpMethod in {HttpPost, HttpPut, HttpConnect, HttpPatch}

# Send data
proc send*(this:HttpRequest, code:HttpCode, content:string) {.async.} =
    var msg = "HTTP/1.1 " & $code & "\c\L"
    # if headers != nil:
    #     msg.addHeaders(headers)
    
    msg.add("Content-Length: ")  
    msg.add(content.len)
    msg.add "\c\L\c\L"
    msg.add(content)
    result = this.ctx.socket.send(msg)

# Send data with ok code
proc sendOk*(this:HttpRequest, content:string) {.async.} =
    await this.send(Http200, content)

# Get http method
template httpMethod*(this:HttpRequest):HttpMethod =
    this.ctx.httpMethod

# Return request path
template path*(this:HttpRequest):string =
    discard

# Get headers
template headers*():string =
    discard

# Get body
template body*():string =
    discard

# 1. Read method
# 2. Read fast end of headers if GET, HEAD
# 3. If other or fast read fail - read headers
# 4. If have body get content-length
# 5. Create stream and process request
proc handleClient(ctx:ClientCtx) {.async.} =
    while true:
        # Read method
        await ctx.readMethodAndUrl()

        # Read headers
        await ctx.readHeaders()        

        # If has body - read body with content-length
        # TODO: create reading stream
        if (ctx.hasBody()):
            discard
            #echo "BODY"
            # read body
        else:
            await ctx.handler(HttpRequest(ctx: ctx))
        
        # TODO: if chunk

# Create new http server
proc newHttpServer*(port = 8080, address = ""):HttpServer =
    result = HttpServer(port:Port(port), address:address)
    let server = newAsyncSocket()
    server.setSockOpt(OptReuseAddr, true)
    server.setSockOpt(OptReusePort, true)    
    result.socket = server

# Run server
proc run*(this:HttpServer, handler:RequestHandler) {.async.} =    
    this.socket.bindAddr(this.port, this.address)
    this.socket.listen()
    while true:
        try:            
            let clientData = await this.socket.acceptAddr()            
            var ctx = newClientCtx(clientData.client, clientData.address, handler)
            await handleClient(ctx)
        except:
            discard
            #echo "ERROR:"
            #let ex = getCurrentException()
            #echo ex.msg