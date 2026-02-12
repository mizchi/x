///|
extern "js" fn js_fetch_internal(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[String] =
  #| async (url, method, headersJson, body) => {
  #|   const headers = JSON.parse(headersJson);
  #|   try {
  #|     const options = { method, headers };
  #|     if (body && method !== 'GET' && method !== 'HEAD') {
  #|       options.body = body;
  #|     }
  #|     const res = await fetch(url, options);
  #|     const resBody = await res.text();
  #|     const resHeaders = {};
  #|     res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|     return JSON.stringify({
  #|       code: res.status,
  #|       reason: res.statusText,
  #|       headers: resHeaders,
  #|       body: resBody,
  #|     });
  #|   } catch (e) {
  #|     throw e;
  #|   }
  #| }

///|
fn parse_response_json(json_str : String) -> (Response, &@io.Data) {
  let parsed = @json.parse(json_str) catch {
    _ => return (Response::{ code: 0, reason: "", headers: {} }, "")
  }
  let code = match parsed {
    Object(map) =>
      match map.get("code") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
    _ => 0
  }
  let reason = match parsed {
    Object(map) =>
      match map.get("reason") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let body : String = match parsed {
    Object(map) =>
      match map.get("body") {
        Some(String(s)) => s
        _ => ""
      }
    _ => ""
  }
  let headers : Map[String, String] = {}
  match parsed {
    Object(map) =>
      match map.get("headers") {
        Some(Object(hmap)) =>
          hmap.each(fn(k, v) {
            match v {
              String(s) => headers[k.to_lower()] = s
              _ => ()
            }
          })
        _ => ()
      }
    _ => ()
  }
  (Response::{ code, reason, headers }, body)
}

// Streaming API

///|
priv struct JsStreamResult {
  id : Int
  code : Int
  reason : String
  headers_json : String
}

///|
priv struct JsStreamChunk {
  done : Bool
  data : Bytes
}

///|
extern "js" fn js_fetch_stream(
  url : String,
  http_method : String,
  headers_json : String,
  body : String,
) -> @js_async.Promise[JsStreamResult] =
  #| async (url, method, headersJson, body) => {
  #|   if (!globalThis.__xhs) globalThis.__xhs = { streams: new Map(), nextId: 1 };
  #|   const headers = JSON.parse(headersJson);
  #|   const options = { method, headers };
  #|   if (body && method !== 'GET' && method !== 'HEAD') {
  #|     options.body = body;
  #|   }
  #|   const res = await fetch(url, options);
  #|   const reader = res.body.getReader();
  #|   const id = globalThis.__xhs.nextId++;
  #|   globalThis.__xhs.streams.set(id, { reader });
  #|   const resHeaders = {};
  #|   res.headers.forEach((v, k) => { resHeaders[k] = v; });
  #|   return { id, code: res.status, reason: res.statusText, headers_json: JSON.stringify(resHeaders) };
  #| }

///|
extern "js" fn js_stream_read(id : Int) -> @js_async.Promise[JsStreamChunk] =
  #| async (id) => {
  #|   const s = globalThis.__xhs.streams.get(id);
  #|   if (!s) throw new Error('Stream not found');
  #|   const { done, value } = await s.reader.read();
  #|   return { done, data: done ? new Uint8Array(0) : value };
  #| }

///|
extern "js" fn js_stream_close(id : Int) -> Unit =
  #| (id) => {
  #|   const s = globalThis.__xhs;
  #|   const st = s.streams.get(id);
  #|   if (st) { st.reader.cancel().catch(() => {}); s.streams.delete(id); }
  #| }

///|
pub struct Stream {
  id : Int
}

///|
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  let parsed = @json.parse(json_str) catch { _ => return headers }
  match parsed {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[k.to_lower()] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}

///|
async fn stream_request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, Stream) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_stream(url, meth, hjson, body_str)
  let result = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  let resp = Response::{
    code: result.code,
    reason: result.reason,
    headers: parse_headers_json(result.headers_json),
  }
  (resp, Stream::{ id: result.id })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  let empty : String = ""
  stream_request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  let controller = @js_async.AbortController::new()
  let promise = js_stream_read(self.id)
  let chunk = @js_async.Promise::wait(promise, abort_controller=controller) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  if chunk.done {
    None
  } else {
    Some(chunk.data)
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let chunks : Array[Bytes] = []
  let mut total = 0
  for {
    match self.read_some() {
      Some(chunk) => {
        chunks.push(chunk)
        total = total + chunk.length()
      }
      None => break
    }
  }
  if chunks.length() == 1 {
    return chunks[0]
  }
  let flat : Array[Byte] = Array::new(capacity=total)
  for chunk in chunks {
    for i = 0; i < chunk.length(); i = i + 1 {
      flat.push(chunk[i])
    }
  }
  Bytes::makei(flat.length(), fn(i) { flat[i] })
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  js_stream_close(self.id)
}

// Non-streaming API

///|
async fn request_internal_js(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, &@io.Data) raise HttpError {
  let hjson = headers_to_json(headers)
  let body_str = body.text() catch { _ => "" }
  let controller = @js_async.AbortController::new()
  let promise = js_fetch_internal(url, meth, hjson, body_str)
  let result_json = @js_async.Promise::wait(
    promise,
    abort_controller=controller,
  ) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  parse_response_json(result_json)
}

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  let empty : String = ""
  request_internal_js(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal_js(url, "PUT", headers.unwrap_or({}), body)
}
