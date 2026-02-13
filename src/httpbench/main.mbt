///|
extern "js" fn js_env_port() -> Int =
  #| () => {
  #|   const raw = Number(process?.env?.PORT || 18080);
  #|   if (!Number.isFinite(raw) || raw <= 0 || raw > 65535) return 18080;
  #|   return raw | 0;
  #| }

///|
fn is_path(req_path : String, expected : String) -> Bool {
  req_path == expected || req_path.has_prefix(expected + "?")
}

///|
async fn main {
  let port = js_env_port()
  let server = @http.Server::new(
    port~,
    request_timeout_ms=0,
    keep_alive_timeout_ms=65000,
    headers_timeout_ms=66000,
  ) catch {
    err => abort("httpbench server init failed: \{err.to_string()}")
  }
  let listen_port = server.port()
  println("httpbench listening on http://127.0.0.1:\{listen_port}")
  server.run_forever(
    (req, body, conn) => {
      if is_path(req.path, "/ping") {
        conn.send_response(200, "OK")
        conn.write("ok")
        conn.end_response()
        return
      }
      if is_path(req.path, "/consume") {
        ignore(body.read_all())
        conn.send_response(204, "No Content")
        conn.end_response()
        return
      }
      if is_path(req.path, "/discard") {
        conn.skip_request_body()
        conn.send_response(204, "No Content")
        conn.end_response()
        return
      }
      if is_path(req.path, "/echo") {
        let payload = body.read_all()
        conn.send_response(200, "OK")
        conn.write(payload)
        conn.end_response()
        return
      }
      conn.skip_request_body()
      conn.send_response(404, "Not Found")
      conn.write("not found")
      conn.end_response()
    },
    allow_failure=false,
  ) catch {
    err => abort("httpbench run failed: \{err.to_string()}")
  }
}
