import asyncdispatch
import craxecore

let server = newHttpServer(26301)
asyncCheck server.run(
    proc(req:HttpRequest) {.async.} =
        await req.sendOk("Hello wordl!")
)

runForever()