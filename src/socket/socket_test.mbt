///|
fn fixed_text(buf : FixedArray[Byte], len : Int) -> String {
  let out = StringBuilder::new()
  for i in 0..<len {
    out.write_char(buf[i].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
suberror TcpServerDone

///|
test "addr parse ipv4" {
  let addr = @socket.Addr::parse("127.0.0.1:8080")
  assert_eq(addr.port(), 8080)
  assert_eq(addr.ip(), 0x7f000001U)
  assert_false(addr.is_ipv6())
  assert_false(addr.is_multicast())
  assert_eq(addr.to_string(), "127.0.0.1:8080")
}

///|
test "addr new multicast" {
  let addr = @socket.Addr::new(0xe00000fbU, 5353)
  assert_eq(addr.port(), 5353)
  assert_true(addr.is_multicast())
  assert_eq(addr.to_string(), "224.0.0.251:5353")
}

///|
async test "udp unicast roundtrip" {
  let server = @socket.UdpServer(@socket.Addr::parse("127.0.0.1:0"))
  defer server.close()
  assert_true(server.addr.port() > 0)

  let client = @socket.UdpClient(server.addr)
  defer client.close()
  client.send(b"ping")

  let server_buf = FixedArray::make(16, b'\x00')
  let (server_n, peer) = server.recvfrom(server_buf)
  assert_eq(server_n, 4)
  assert_eq(fixed_text(server_buf, server_n), "ping")
  assert_eq(peer.ip(), 0x7f000001U)

  server.sendto(b"pong", peer)
  let client_buf = FixedArray::make(16, b'\x00')
  let client_n = client.recv(client_buf)
  assert_eq(client_n, 4)
  assert_eq(fixed_text(client_buf, client_n), "pong")
}

///|
async test "tcp roundtrip" {
  @async.with_task_group(root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr
    assert_true(addr.port() > 0)

    root.spawn_bg(() => {
      defer server.close()
      let (conn, peer) = server.accept()
      defer conn.close()
      assert_eq(peer.ip(), 0x7f000001U)
      let server_buf = FixedArray::make(16, b'\x00')
      let server_n = conn.read(server_buf)
      assert_eq(server_n, 4)
      assert_eq(fixed_text(server_buf, server_n), "ping")
      conn.write("pong")
    })

    root.spawn_bg(() => {
      let conn = @socket.Tcp::connect(addr)
      defer conn.close()
      assert_true(conn.addr.port() > 0)
      conn.write("ping")
      let client_buf = FixedArray::make(16, b'\x00')
      let client_n = conn.read(client_buf)
      assert_eq(client_n, 4)
      assert_eq(fixed_text(client_buf, client_n), "pong")
    })
  })
}

///|
async test "tcp run_forever" {
  let mut seen = ""
  @async.with_task_group(root => {
    let server = @socket.TcpServer(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr

    root.spawn_bg(() => {
      server.run_forever(allow_failure=false, (conn, _peer) => {
        let server_buf = FixedArray::make(16, b'\x00')
        let server_n = conn.read(server_buf)
        seen = fixed_text(server_buf, server_n)
        conn.write("done")
        raise TcpServerDone
      }) catch {
        TcpServerDone => ()
        err => raise err
      }
    })

    root.spawn_bg(() => {
      let conn = @socket.Tcp::connect(addr)
      defer conn.close()
      conn.write("ping")
      let client_buf = FixedArray::make(16, b'\x00')
      let client_n = conn.read(client_buf)
      assert_eq(client_n, 4)
      assert_eq(fixed_text(client_buf, client_n), "done")
    })
  })
  assert_eq(seen, "ping")
}
