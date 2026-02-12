///|
async test "http GET" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      guard req.meth is Get else { fail("expected GET") }
      conn.send_response(200, "OK")
      conn.write("hello from server")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://localhost:\{addr.port()}/test")
    assert_eq(resp.code, 200)
    assert_eq(resp.reason, "OK")
    assert_eq(body.text(), "hello from server")
  })
}

///|
async test "http POST with body" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Post else { fail("expected POST") }
      let body = conn.read_all()
      conn.send_response(201, "Created")
      conn.write("received: " + body.text())
      conn.end_response()
    })
    let post_body : String = "test data"
    let (resp, body) = @http.post(
      "http://localhost:\{addr.port()}/items",
      post_body,
    )
    assert_eq(resp.code, 201)
    assert_eq(resp.reason, "Created")
    assert_eq(body.text(), "received: test data")
  })
}

///|
async test "http PUT with body" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      guard req.meth is Put else { fail("expected PUT") }
      let body = conn.read_all()
      conn.send_response(200, "OK")
      conn.write("updated: " + body.text())
      conn.end_response()
    })
    let put_body : String = "updated data"
    let (resp, body) = @http.put(
      "http://localhost:\{addr.port()}/items/1",
      put_body,
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "updated: updated data")
  })
}

///|
async test "http GET with custom headers" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      let auth = req.headers.get("authorization").unwrap_or("none")
      conn.send_response(200, "OK")
      conn.write("auth: " + auth)
      conn.end_response()
    })
    let headers : Map[String, String] = {
      "Authorization": "Bearer token123",
    }
    let (resp, body) = @http.get(
      "http://localhost:\{addr.port()}/secure",
      headers~,
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "auth: Bearer token123")
  })
}

///|
async test "http response headers" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      let extra_headers : Map[String, String] = {
        "X-Custom": "custom-value",
        "Content-Type": "text/plain",
      }
      conn.send_response(200, "OK", extra_headers~)
      conn.write("ok")
      conn.end_response()
    })
    let (resp, _) = @http.get("http://localhost:\{addr.port()}/")
    assert_eq(resp.code, 200)
    assert_eq(resp.headers.get("x-custom").unwrap_or(""), "custom-value")
    assert_eq(resp.headers.get("content-type").unwrap_or(""), "text/plain")
  })
}

///|
async test "http 404 response" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(404, "Not Found")
      conn.write("not found")
      conn.end_response()
    })
    let (resp, body) = @http.get(
      "http://localhost:\{addr.port()}/missing",
    )
    assert_eq(resp.code, 404)
    assert_eq(resp.reason, "Not Found")
    assert_eq(body.text(), "not found")
  })
}

///|
async test "http empty body" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(204, "No Content")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://localhost:\{addr.port()}/empty")
    assert_eq(resp.code, 204)
    assert_eq(body.text(), "")
  })
}

///|
async test "http unicode body" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      ignore(conn.read_request())
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write("\u{3053}\u{3093}\u{306B}\u{3061}\u{306F}\u{4E16}\u{754C}")
      conn.end_response()
    })
    let (resp, body) = @http.get("http://localhost:\{addr.port()}/unicode")
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "\u{3053}\u{3093}\u{306B}\u{3061}\u{306F}\u{4E16}\u{754C}")
  })
}

///|
async test "smoke: GET matches upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      // Handle two requests: upstream then wrapper
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        conn.skip_request_body()
        conn.send_response(200, "OK")
        conn.write("path=" + req.path)
        conn.end_response()
        conn.close()
      }
    })
    let url = "http://localhost:\{addr.port()}/test"
    // Upstream
    let upstream_client = @async_http.Client::new("http://localhost:\{addr.port()}")
    defer upstream_client.close()
    let upstream_resp = upstream_client.get("/test")
    let upstream_body = upstream_client.read_all()
    // Wrapper
    let (wrapper_resp, wrapper_body) = @http.get(url)
    // Compare
    assert_eq(upstream_resp.code, wrapper_resp.code)
    assert_eq(upstream_body.text(), wrapper_body.text())
    assert_eq(upstream_body.text(), "path=/test")
  })
}

///|
async test "smoke: POST matches upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        ignore(conn.read_request())
        let body = conn.read_all()
        conn.send_response(201, "Created")
        conn.write("echo:" + body.text())
        conn.end_response()
        conn.close()
      }
    })
    let post_data : String = "payload"
    // Upstream
    let upstream_client = @async_http.Client::new("http://localhost:\{addr.port()}")
    defer upstream_client.close()
    let upstream_resp = upstream_client.post("/api", post_data)
    let upstream_body = upstream_client.read_all()
    // Wrapper
    let (wrapper_resp, wrapper_body) = @http.post(
      "http://localhost:\{addr.port()}/api",
      post_data,
    )
    // Compare
    assert_eq(upstream_resp.code, wrapper_resp.code)
    assert_eq(upstream_resp.reason, wrapper_resp.reason)
    assert_eq(upstream_body.text(), wrapper_body.text())
    assert_eq(upstream_body.text(), "echo:payload")
  })
}

///|
async test "http multi-part response" {
  // Adapted from upstream "request streaming" test
  // Server sends response in multiple writes, client receives full body
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      let (conn, _) = server.accept()
      defer conn.close()
      let req = conn.read_request()
      conn.skip_request_body()
      conn.send_response(200, "OK")
      conn.write("part1-" + req.path + "\n")
      conn.flush()
      conn.write("part2-" + req.path + "\n")
      conn.end_response()
    })
    let (resp, body) = @http.get(
      "http://localhost:\{addr.port()}/multi",
    )
    assert_eq(resp.code, 200)
    assert_eq(body.text(), "part1-/multi\npart2-/multi\n")
  })
}

///|
async test "http POST echo - request method and path" {
  // Adapted from upstream "request streaming": server echoes method+path
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 3; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        let body = conn.read_all()
        conn.send_response(200, "OK")
        conn.write(req.meth.to_string() + " " + req.path + " body=" + body.text())
        conn.end_response()
        conn.close()
      }
    })
    let port = addr.port()
    // GET
    let (_, get_body) = @http.get("http://localhost:\{port}/get")
    assert_eq(get_body.text(), "Get /get body=")
    // POST
    let post_data : String = "data1"
    let (_, post_body) = @http.post(
      "http://localhost:\{port}/post",
      post_data,
    )
    assert_eq(post_body.text(), "Post /post body=data1")
    // PUT
    let put_data : String = "data2"
    let (_, put_body) = @http.put(
      "http://localhost:\{port}/put",
      put_data,
    )
    assert_eq(put_body.text(), "Put /put body=data2")
  })
}

///|
async test "http multiple sequential requests" {
  // Adapted from upstream "request streaming": multiple requests on same server
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 5; i = i + 1 {
        let (conn, _) = server.accept()
        let req = conn.read_request()
        conn.skip_request_body()
        conn.send_response(200, "OK")
        conn.write("req-" + i.to_string() + "-" + req.path)
        conn.end_response()
        conn.close()
      }
    })
    let port = addr.port()
    for i = 0; i < 5; i = i + 1 {
      let (resp, body) = @http.get(
        "http://localhost:\{port}/path\{i}",
      )
      assert_eq(resp.code, 200)
      assert_eq(body.text(), "req-" + i.to_string() + "-/path" + i.to_string())
    }
  })
}

///|
async test "https request" {
  // Same as upstream "https request"
  let (_, result) = @http.get("https://www.example.org")
  assert_true(result.text().has_prefix("<!doctype html>"))
}

///|
async test "http request" {
  // Same as upstream "http request"
  let (_, result) = @http.get("http://www.example.org")
  assert_true(result.text().has_prefix("<!doctype html>"))
}

///|
async test "smoke: response headers match upstream" {
  @async.with_task_group(group => {
    let server = @async_http.Server::new(@socket.Addr::parse("127.0.0.1:0"))
    let addr = server.addr()
    group.spawn_bg(() => {
      defer server.close()
      for i = 0; i < 2; i = i + 1 {
        let (conn, _) = server.accept()
        ignore(conn.read_request())
        conn.skip_request_body()
        let extra : Map[String, String] = { "X-Test": "value123" }
        conn.send_response(200, "OK", extra_headers=extra)
        conn.write("ok")
        conn.end_response()
        conn.close()
      }
    })
    // Upstream
    let upstream_client = @async_http.Client::new("http://localhost:\{addr.port()}")
    defer upstream_client.close()
    let upstream_resp = upstream_client.get("/")
    ignore(upstream_client.read_all())
    let upstream_header = upstream_resp.headers.get("x-test").unwrap_or("")
    // Wrapper
    let (wrapper_resp, _) = @http.get(
      "http://localhost:\{addr.port()}/",
    )
    let wrapper_header = wrapper_resp.headers.get("x-test").unwrap_or("")
    // Compare
    assert_eq(upstream_header, wrapper_header)
    assert_eq(upstream_header, "value123")
  })
}
