///|
extern "js" fn js_now_ms() -> Int =
  #| () => Date.now() | 0

///|
async test "server(js): max_request_body_bytes returns 413" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0, max_request_body_bytes=4)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, body, conn) => {
        let payload = body.read_all()
        conn.send_response(200, "OK")
        conn.write("ok:" + payload.text())
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.post("http://127.0.0.1:\{port}/limit", "abcdef")
    assert_eq(resp.code, 413)
    assert_true(body.text().contains("request body too large"))
  })
}

///|
async test "server(js): close_graceful closes listener" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        conn.send_response(200, "OK")
        conn.write("ok")
        conn.end_response()
      })
    })
    @async.sleep(20)
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/before-close")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")

    server.close_graceful(timeout_ms=500)
    @async.sleep(20)

    let after_close : Result[(@http.Response, &@io.Data), @http.HttpError] = try? @http.get(
      "http://127.0.0.1:\{port}/after-close",
    )
    assert_true(after_close is Err(_))
  })
}

///|
async test "server(js): enter_passthrough_mode is callable after response end" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever(
        (_req, _body, conn) => {
          conn.send_response(200, "OK")
          conn.write("ok")
          conn.end_response()
          conn.enter_passthrough_mode()
          conn.close()
        },
        allow_failure=true,
      )
    })
    @async.sleep(20)
    let (resp, body) = @http.post(
      "http://127.0.0.1:\{port}/passthrough",
      "abcdef",
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
  })
}

///|
async test "server(js): close_graceful finishes with active sse" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()

    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        let headers : Map[String, String] = {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          "Connection": "keep-alive",
        }
        conn.send_response(200, "OK", extra_headers=headers)
        conn.write("data: first\n\n")
        conn.flush()
        @async.sleep(150)
        conn.write("data: second\n\n")
        conn.end_response()
      })
    })

    @async.sleep(20)
    let (resp, stream) = @http.get_stream("http://127.0.0.1:\{port}/events")
    defer stream.close()
    assert_eq(resp.code, 200)

    let _ = match stream.read_some() {
      Some(chunk) => chunk
      None => fail("expected first sse chunk")
    }

    let mut graceful_done = false
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.close_graceful(timeout_ms=1000)
      graceful_done = true
    })

    let rest = stream.read_all()
    let rest_data : &@io.Data = rest
    assert_true(rest_data.text().contains("data: second"))

    for _ in 0..<60 {
      if graceful_done {
        break
      }
      @async.sleep(20)
    }
    assert_true(graceful_done)

    let after_close : Result[(@http.Response, &@io.Data), @http.HttpError] = try? @http.get(
      "http://127.0.0.1:\{port}/after-close-sse",
    )
    assert_true(after_close is Err(_))
  })
}

///|
async test "server(js): trust_proxy uses x-forwarded-for and x-forwarded-port" {
  @async.with_task_group(group => {
    let server = @http.Server::new(port=0, trust_proxy=true)
    defer server.close()
    let port = server.port()
    let seen : Array[@http.Addr] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      server.run_forever((_req, _body, conn) => {
        seen.push(conn.client_addr())
        conn.send_response(200, "OK")
        conn.write("ok")
        conn.end_response()
      })
    })
    @async.sleep(20)
    let headers : Map[String, String] = {
      "X-Forwarded-For": "203.0.113.99, 10.0.0.1",
      "X-Forwarded-Port": "443",
    }
    let (resp, body) = @http.get("http://127.0.0.1:\{port}/trusted", headers~)
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "ok")
    assert_eq(seen.length(), 1)
    assert_eq(seen[0].text, "203.0.113.99:443")
    assert_eq(seen[0].port, 443)
  })
}

///|
async test "bench(js): graceful close time under concurrent sse" {
  @async.with_task_group(group => {
    let clients = 24
    let server = @http.Server::new(port=0)
    defer server.close()
    let port = server.port()
    let accepted_conns : Array[@http.ServerConnection] = []
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      let headers : Map[String, String] = {
        "Content-Type": "text/event-stream",
        "Cache-Control": "no-cache",
        "Connection": "keep-alive",
      }
      for _ in 0..<(clients + 8) {
        let accepted : Result[
          (@http.ServerConnection, @http.Addr),
          @http.HttpError,
        ] = try? server.accept()
        match accepted {
          Ok((conn, _peer)) => {
            ignore(conn.read_request())
            conn.skip_request_body()
            conn.send_response(200, "OK", extra_headers=headers)
            conn.write("data: bench-start\n\n")
            conn.flush()
            accepted_conns.push(conn)
          }
          Err(_) => break
        }
      }
    })

    let streams : Array[@http.Stream] = []
    for _ in 0..<clients {
      let (resp, stream) = @http.get_stream("http://127.0.0.1:\{port}/bench")
      assert_eq(resp.code, 200)
      let first = stream.read_some()
      assert_true(first is Some(_))
      streams.push(stream)
    }
    assert_true(accepted_conns.length() >= clients)

    let started = js_now_ms()
    server.close_graceful(timeout_ms=1500)
    let elapsed = js_now_ms() - started
    println("bench(js): sse_clients=\{clients} graceful_close_ms=\{elapsed}")
    assert_true(elapsed >= 0)
    assert_true(elapsed < 2500)

    for stream in streams {
      stream.close()
    }
  })
}
