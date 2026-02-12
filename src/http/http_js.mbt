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
