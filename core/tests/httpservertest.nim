import asyncdispatch
import craxecore

let server = newHttpServer(26301)
server.run(
    proc(req:HttpRequest) {.async.} =
        discard
)

runForever()