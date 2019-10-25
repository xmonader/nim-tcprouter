# This is just an example to get you started. A typical binary package
# uses this file as the main entry point of the application.

import  strformat, tables, json, strutils, sequtils, hashes, net, asyncdispatch, asyncnet, os, strutils, parseutils, deques, options, net

type ForwardOptions = object
  listenAddr*: string
  listenPort*: Port
  toAddr*: string
  toPort*: Port

type Forwarder = object of RootObj
  options*: ForwardOptions

proc processClient(this: ref Forwarder, client: AsyncSocket) {.async.} =
  let remote = newAsyncSocket(buffered=false)
  await remote.connect(this.options.toAddr, this.options.toPort)

  proc clientHasData() {.async.} =
    while not client.isClosed and not remote.isClosed:
      echo "in client has data loop"
      let data = await client.recv(1024)
      echo "got data: " & data
      try:
        await remote.send(data)
      except:
        echo getCurrentExceptionMsg()
    client.close()
    remote.close()

  proc remoteHasData() {.async.} =
    while not remote.isClosed and not client.isClosed:
      echo " in remote has data loop"
      let data = await remote.recv(1024)
      echo "got data: " & data
      try:
        await client.send(data)
      except:
        echo getCurrentExceptionMsg()
    client.close()
    remote.close()
  
  try:
    asyncCheck clientHasData()
    asyncCheck remoteHasData()
  except:
    echo getCurrentExceptionMsg()

proc serve(this: ref Forwarder) {.async.} =
  var server = newAsyncSocket(buffered=false)
  server.setSockOpt(OptReuseAddr, true)
  server.bindAddr(this.options.listenPort, this.options.listenAddr)
  echo fmt"Started tcp server... {this.options.listenAddr}:{this.options.listenPort} "
  server.listen()
  
  while true:
    let client = await server.accept()
    echo "..Got connection "

    asyncCheck this.processClient(client)

proc newForwarder(opts: ForwardOptions): ref Forwarder =
  result = new(Forwarder)
  result.options = opts

let opts = ForwardOptions(listenAddr:"127.0.0.1", listenPort:11000.Port, toAddr:"127.0.0.1", toPort:8000.Port)
var f = newForwarder(opts)
asyncCheck f.serve()
runForever()
