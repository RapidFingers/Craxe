import selectors, net, nativesockets, os, asyncdispatch, httpcore
import times, strutils, parseutils, options
import uri
from deques import len

type
    FdKind = enum
        Server, Client, Dispatcher

    CommonHandle = SocketHandle|int

    SelectorData = object
        case fdKind: FdKind
        of Server:
            discard
        of Client:
            address:string
            data:string
            # Determines whether `data` contains "\c\l\c\l".
            headersFinished:bool
            # Determines position of the end of "\c\l\c\l".
            headersFinishPos:int
            # A queue of data that needs to be sent when the FD becomes writeable.
            sendQueue: string
            # The number of characters in `sendQueue` that have been sent already.
            bytesSent: int
        of Dispatcher:
            discard

    HttpRequest* = ref object
        server:HttpServer
        selectorData: ptr SelectorData
        clientFd: SocketHandle
        start:int
        reqHttpMethod:HttpMethod
        reqUrl:Uri

    HttpResponse* = ref object

    HttpServer* = ref object
        socket:Socket
        selector:Selector[SelectorData]
        date:string
        port:Port
        address:string
        handler:RequestHandler

    RequestHandler* = proc(req:HttpRequest, resp:HttpResponse):Future[void] {.gcsafe.}

proc parseHttpMethod*(data: string, start: int): Option[HttpMethod] =
    ## Parses the data to find the request HttpMethod.
    
    # HTTP methods are case sensitive.
    # (RFC7230 3.1.1. "The request method is case-sensitive.")
    case data[start]
    of 'G':
        if data[start+1] == 'E' and data[start+2] == 'T':
            return some(HttpGet)
    of 'H':
        if data[start+1] == 'E' and data[start+2] == 'A' and data[start+3] == 'D':
            return some(HttpHead)
    of 'P':
        if data[start+1] == 'O' and data[start+2] == 'S' and data[start+3] == 'T':
            return some(HttpPost)
        if data[start+1] == 'U' and data[start+2] == 'T':
            return some(HttpPut)
        if data[start+1] == 'A' and data[start+2] == 'T' and
            data[start+3] == 'C' and data[start+4] == 'H':
            return some(HttpPatch)
    of 'D':
        if data[start+1] == 'E' and data[start+2] == 'L' and
            data[start+3] == 'E' and data[start+4] == 'T' and
            data[start+5] == 'E':
            return some(HttpDelete)
    of 'O':
        if data[start+1] == 'P' and data[start+2] == 'T' and
            data[start+3] == 'I' and data[start+4] == 'O' and
            data[start+5] == 'N' and data[start+6] == 'S':
            return some(HttpOptions)
    else: 
        discard
    
    return none(HttpMethod)

proc parsePath*(data: string, start: int): Option[string] =
    ## Parses the request path from the specified data.

    # Find the first ' '.
    # We can actually start ahead a little here. Since we know
    # the shortest HTTP method: 'GET'/'PUT'.
    var i = start+2
    while data[i] notin {' ', '\0'}: i.inc()

    if likely(data[i] == ' '):
        # Find the second ' '.
        i.inc() # Skip first ' '.
        let start = i
        while data[i] notin {' ', '\0'}: i.inc()

        if likely(data[i] == ' '):
            return some(data[start..<i])
    else:
        return none(string)

proc parseHeaders*(data: string, start: int): Option[HttpHeaders] =
  var pairs: seq[(string, string)] = @[]

  var i = start
  # Skip first line containing the method, path and HTTP version.
  while data[i] != '\l': i.inc

  i.inc # Skip \l

  var value = false
  var current: (string, string) = ("", "")
  while i < data.len:
    case data[i]
    of ':':
        if value: current[1].add(':')
        value = true
    of ' ':
        if value:
            if current[1].len != 0:
                current[1].add(data[i])
        else:
            current[0].add(data[i])
    of '\c':
        discard
    of '\l':
        if current[0].len == 0:
            # End of headers.
            return some(newHttpHeaders(pairs))
        
        pairs.add(current)
        value = false
        current = ("", "")
    else:
        if value:
            current[1].add(data[i])
        else:
            current[0].add(data[i])
    i.inc()

    return none(HttpHeaders)

iterator parseRequests*(data: string): int =
    ## Yields the start position of each request in `data`.
    ##
    ## This is only necessary for support of HTTP pipelining. The assumption
    ## is that there is a request at position `0`, and that there MAY be another
    ## request further in the data buffer.
    var i = 0
    yield i

    while i+3 < len(data):
        if data[i+0] == '\c' and data[i+1] == '\l' and data[i+2] == '\c' and data[i+3] == '\l':
            if likely(i+4 == len(data)): 
                break
            i.inc(4)
            if parseHttpMethod(data, i).isNone(): 
                continue
            yield i

        i.inc()

proc parseContentLength*(data: string, start: int): int =
    result = 0
    
    let headers = data.parseHeaders(start)
    if headers.isNone(): return
    
    if unlikely(not headers.get().hasKey("Content-Length")): return
    
    discard headers.get()["Content-Length"].parseSaturatedNatural(result)      

# Update server time
template updateDate(this:HttpServer) =
    this.date = now().utc().format("ddd, dd MMM yyyy HH:mm:ss 'GMT'")

# Handle client accept
template handleAccept(this:HttpServer) =
    let (client, address) = fd.SocketHandle.accept()
    if client == osInvalidSocket:
        let lastError = osLastError()
        raiseOSError(lastError)
    setBlocking(client, false)
    this.selector.registerHandle(
        client,
        {Event.Read}, 
        SelectorData(
            fdKind: Client,
            address: address
        )
    )

# Close client
template closeClient(
                    this:HttpServer,
                    fd:CommonHandle) =
    this.selector.unregister(fd)
    fd.SocketHandle.close()

template fastHeadersCheck(selectorData: ptr SelectorData): untyped =
    (let res = selectorData.data[^1] == '\l' and selectorData.data[^2] == '\c' and
        selectorData.data[^3] == '\l' and selectorData.data[^4] == '\c';
        if res: selectorData.headersFinishPos = selectorData.data.len;
        res
    )

template methodNeedsBody(selectorData: ptr SelectorData): untyped =
    (
        # Only idempotent methods can be pipelined (GET/HEAD/PUT/DELETE), they
        # never need a body, so we just assume `start` at 0.
        let m = parseHttpMethod(selectorData.data, start=0);
        m.isSome() and m.get() in {HttpPost, HttpPut, HttpConnect, HttpPatch}
    )

proc slowHeadersCheck(data: ptr SelectorData): bool =
    # TODO: See how this `unlikely` affects ASM.
    if unlikely(methodNeedsBody(data)):
        # Look for \c\l\c\l inside data.
        data.headersFinishPos = 0
        template ch(i): untyped =
            (
                let pos = data.headersFinishPos+i;
                if pos >= data.data.len: '\0' else: data.data[pos]
            )
        while data.headersFinishPos < data.data.len:
            case ch(0)
            of '\c':
                if ch(1) == '\l' and ch(2) == '\c' and ch(3) == '\l':
                    data.headersFinishPos.inc(4)
                    return true
            else: 
                discard
            data.headersFinishPos.inc()

        data.headersFinishPos = -1

proc bodyInTransit(data: ptr SelectorData): bool =
    assert methodNeedsBody(data), "Calling bodyInTransit now is inefficient."
    assert data.headersFinished
    
    if data.headersFinishPos == -1: 
        return false
    
    var trueLen = parseContentLength(data.data, start=0)
    
    let bodyLen = data.data.len - data.headersFinishPos
    assert(not (bodyLen > trueLen))
    return bodyLen != trueLen

proc send*(req: HttpRequest, code: HttpCode, body: string, headers="") =
    ## Responds with the specified HttpCode and body.
    ##
    ## **Warning:** This can only be called once in the OnRequest callback.

    if req.clientFd notin req.server.selector:
        return

    let otherHeaders = if likely(headers.len == 0): "" else: "\c\L" & headers
    var
        text = (
            "HTTP/1.1 $#\c\L" &
            "Content-Length: $#\c\LServer: $#\c\LDate: $#$#\c\L\c\L$#"
        ) % [$code, $body.len, "Craxe", req.server.date, otherHeaders, body]

    req.selectorData.sendQueue.add(text)
    req.server.selector.updateHandle(req.clientFd, {Event.Read, Event.Write})

template send*(req: HttpRequest, code: HttpCode) =
    ## Responds with the specified HttpCode. The body of the response
    ## is the same as the HttpCode description.
    req.send(code, $code)

template send*(req: HttpRequest, body: string, code = Http200) =
    ## Sends a HTTP 200 OK response with the specified body.
    ##
    ## **Warning:** This can only be called once in the OnRequest callback.
    req.send(code, body)

template sendOk*(req: HttpRequest, body: string) =
    req.send(body)

template httpMethod*(req: HttpRequest): HttpMethod =
    req.reqHttpMethod

template url*(req: HttpRequest):Uri =
    req.reqUrl

# Process read client events
template processReadClientEvents(this:HttpServer, fd:CommonHandle, selectorData:ptr SelectorData) =
    const size = 256
    var buf: array[size, char]
    # Read until EAGAIN. We take advantage of the fact that the client
    # will wait for a response after they send a request. So we can
    # comfortably continue reading until the message ends with \c\l
    # \c\l.
    while true:        
        let ret = recv(fd.SocketHandle, addr buf[0], size, 0.cint)
        if ret == 0:
            this.closeClient(fd)
            break

        if ret == -1:
            let lastError = osLastError()
            if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
                break
            if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
                this.closeClient(fd)
                break            
            raiseOSError(lastError)

        # Write buffer to our data
        # TODO: copy memory?
        let origLen = selectorData.data.len
        selectorData.data.setLen(origLen + ret)
        for i in 0 ..< ret: selectorData.data[origLen+i] = buf[i]

        if fastHeadersCheck(selectorData) or slowHeadersCheck(selectorData):
            # First line and headers for request received.
            selectorData.headersFinished = true                                

            let waitingForBody = methodNeedsBody(selectorData) and bodyInTransit(selectorData)
            if likely(not waitingForBody):
                for start in parseRequests(selectorData.data):
                    # For pipelined requests, we need to reset this flag.
                    selectorData.headersFinished = true
                    
                    let path = parsePath(selectorData.data, start)
                    let url = parseUri(path.get())
                    let meth = parseHttpMethod(selectorData.data, start)

                    var request = HttpRequest(
                        server:this,
                        selectorData: selectorData,
                        clientFd: fd.SocketHandle,
                        start: start,
                        reqHttpMethod: meth.get(),
                        reqUrl: url
                    )       

                    var response = HttpResponse()             
                    
                    var fut = this.handler(request, response)
                    if not fut.isNil:                            
                        fut.callback =
                            proc (theFut: Future[void]) =
                                if theFut.failed:
                                    raise theFut.error
                                selectorData.headersFinished = false                    

        if ret != size:
            # Assume there is nothing else for us right now and break.
            break

# Process write client events
template processWriteClientEvents(this:HttpServer, fd:CommonHandle, selectorData:ptr SelectorData) =
    assert selectorData.sendQueue.len > 0
    assert selectorData.bytesSent < selectorData.sendQueue.len
    # Write the sendQueue.
    let leftover = selectorData.sendQueue.len - selectorData.bytesSent
    let ret = send(fd.SocketHandle, addr selectorData.sendQueue[selectorData.bytesSent],
                leftover, 0)
    if ret == -1:
        # Error!
        let lastError = osLastError()
        if lastError.int32 in {EWOULDBLOCK, EAGAIN}:
            break
        if isDisconnectionError({SocketFlag.SafeDisconn}, lastError):
            this.closeClient(fd)
        raiseOSError(lastError)

    selectorData.bytesSent.inc(ret)

    if selectorData.sendQueue.len == selectorData.bytesSent:
        selectorData.bytesSent = 0
        selectorData.sendQueue.setLen(0)
        selectorData.data.setLen(0)
        this.selector.updateHandle(fd.SocketHandle, {Event.Read})

# Process events
proc processEvents(this:HttpServer) =
    var events: array[64, ReadyKey]
    while true:
        let count = this.selector.selectInto(-1, events)        
        
        for i in 0 ..< count:
            let fd = events[i].fd
            var selectorData: ptr SelectorData = addr(this.selector.getData(fd))
            # Handle error events first.
            if Event.Error in events[i].events:
                if isDisconnectionError({SocketFlag.SafeDisconn},events[i].errorCode):
                    this.closeClient(fd)
                    break
                raiseOSError(events[i].errorCode)
                        
            case selectorData.fdKind
            of Server:
                if Event.Read in events[i].events:
                    this.handleAccept()
                else:
                    assert false, "Only Read events are expected for the server"
            of Dispatcher:
                # Run the dispatcher loop.
                assert events[i].events == {Event.Read}
                asyncdispatch.poll(0)
            of Client:
                if Event.Read in events[i].events:
                    this.processReadClientEvents(fd, selectorData)
                elif Event.Write in events[i].events:                    
                    this.processWriteClientEvents(fd, selectorData)
                else:
                    assert false
                    
        # Ensure callbacks list doesn't grow forever in asyncdispatch.
        # See https://github.com/nim-lang/Nim/issues/7532.
        # Not processing callbacks can also lead to exceptions being silently
        # lost!
        if unlikely(asyncdispatch.getGlobalDispatcher().callbacks.len > 0):
            asyncdispatch.poll(0)

# Create new http server
proc newHttpServer*(port = 8080, address = ""):HttpServer =
    let socket = newSocket()
    socket.setSockOpt(OptReuseAddr, true)
    socket.setSockOpt(OptReusePort, true)
    socket.bindAddr(Port(port), address)
    socket.listen()
    socket.getFd().setBlocking(false)
    
    return HttpServer(
        socket: socket,
        selector: newSelector[SelectorData](),
        port: Port(port),
        address: address
    )

# Run server
proc run*(this:HttpServer, handler:RequestHandler) {.async.} =
    this.handler = handler
    this.selector.registerHandle(
            this.socket.getFd(), 
            {Event.Read}, 
            SelectorData(fdKind: Server)
    )

    let disp = getGlobalDispatcher()
    this.selector.registerHandle(
            getIoHandler(disp).getFd(), 
            {Event.Read}, 
            SelectorData(fdKind: Dispatcher)
    )
    # Set up timer to get current date/time.
    this.updateDate()
    asyncdispatch.addTimer(1000, false, 
        proc(v:AsyncFD):bool =
            this.updateDate()
            false
    )

    processEvents(this)