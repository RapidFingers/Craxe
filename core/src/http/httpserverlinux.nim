import selectors, net, nativesockets, os, asyncdispatch
import times, strutils
from deques import len

type
    FdKind = enum
        Server, Client, Dispatcher

    SelectorData = object
        case fdKind: FdKind
        of Server:
            discard
        of Client:
            address:string
        of Dispatcher:
            discard

    HttpRequest* = ref object

    HttpServer* = ref object
        socket:Socket
        selector:Selector[SelectorData]
        date:string
        port:Port
        address:string
        handler:RequestHandler

    RequestHandler* = proc(req:HttpRequest):Future[void] {.gcsafe.}

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
template handleClientClosure(
                    this:HttpServer,
                    fd:SocketHandle|int,
                    inLoop=true) =
    this.selector.unregister(fd)
    fd.SocketHandle.close()
    when inLoop:
        break
    else:
        return

# Process client events
template processClientEvents(this:HttpServer, fd:SocketHandle|int) =
    const size = 256
    var buf: array[size, char]
    # Read until EAGAIN. We take advantage of the fact that the client
    # will wait for a response after they send a request. So we can
    # comfortably continue reading until the message ends with \c\l
    # \c\l.
    while true:
        let ret = recv(fd.SocketHandle, addr buf[0], size, 0.cint)
        if ret == 0:
            this.handleClientClosure(fd)

# Process events
proc processEvents(this:HttpServer) =
    var events: array[64, ReadyKey]
    while true:
        let count = this.selector.selectInto(-1, events)        
        
        for i in 0 ..< count:
            let fd = events[i].fd
            var data: ptr SelectorData = addr(this.selector.getData(fd))
            # Handle error events first.
            if Event.Error in events[i].events:
                if isDisconnectionError({SocketFlag.SafeDisconn},events[i].errorCode):
                    this.handleClientClosure(fd)
                raiseOSError(events[i].errorCode)
            
            case data.fdKind
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
                    this.processClientEvents(fd)
                    
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