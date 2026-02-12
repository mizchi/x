///|
async test "websocket text echo" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("hello")
    let msg = client.recv()
    guard msg is @websocket.Text(text) else { fail("expected Text message") }
    assert_eq(text, "hello")
    client.send_close()
  })
}

///|
async test "websocket binary echo" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    let data = Bytes::makei(4, fn(i) { (i + 65).to_byte() })
    client.send_binary(data[:])
    let msg = client.recv()
    guard msg is @websocket.Binary(received) else {
      fail("expected Binary message")
    }
    assert_eq(received.length(), 4)
    assert_eq(received[0], b'\x41')
    assert_eq(received[1], b'\x42')
    assert_eq(received[2], b'\x43')
    assert_eq(received[3], b'\x44')
    client.send_close()
  })
}

///|
async test "websocket multiple messages" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      for {
        let msg = ws.recv() catch {
          @async_ws.ConnectionClosed(_) => break
          err => raise err
        }
        let content = msg.read_all()
        match msg.kind {
          @async_ws.Text => ws.send_text(content.text())
          @async_ws.Binary => ws.send_binary(content.binary()[:])
        }
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_text("first")
    let msg1 = client.recv()
    guard msg1 is @websocket.Text(t1) else { fail("expected Text") }
    assert_eq(t1, "first")
    client.send_text("second")
    let msg2 = client.recv()
    guard msg2 is @websocket.Text(t2) else { fail("expected Text") }
    assert_eq(t2, "second")
    client.send_text("third")
    let msg3 = client.recv()
    guard msg3 is @websocket.Text(t3) else { fail("expected Text") }
    assert_eq(t3, "third")
    client.send_close()
  })
}

///|
async test "websocket close with code" {
  @async.with_task_group(group => {
    let server = @http_server.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let request = conn.read_request()
      let ws = @async_ws.from_http_server(request, conn)
      defer ws.close()
      try ws.recv() catch {
        @async_ws.ConnectionClosed(code, _) => inspect(code, content="Normal")
        err => raise err
      } noraise {
        _ => ()
      }
    })
    let client = @websocket.Conn::connect("ws://localhost:\{addr.port()}")
    defer client.close()
    client.send_close(code=@websocket.Normal)
  })
}
