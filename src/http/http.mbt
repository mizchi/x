///|
pub(all) struct Response {
  code : Int
  reason : String
  headers : Map[String, String]
  cookies : Array[Cookie]
}

///|
pub struct Cookie {
  name : String
  value : String
  path : String?
  expires_raw : String?
  max_age : Int64?
  domain : String?
  secure : Bool
  http_only : Bool
  extensions : Array[String]
} derive(@debug.Debug)

///|
#alias(new, deprecated)
pub fn Cookie::Cookie(
  name : String,
  value : String,
  path? : String,
  expires_raw? : String,
  max_age? : Int64,
  domain? : String,
  secure? : Bool = false,
  http_only? : Bool = false,
  extensions? : Array[String] = [],
) -> Cookie {
  {
    name,
    value,
    path,
    expires_raw,
    max_age,
    domain,
    secure,
    http_only,
    extensions,
  }
}

///|
fn Cookie::parse(line : StringView) -> Cookie raise {
  guard line.find("=") is Some(name_end) else {
    raise HttpError::InvalidUrl("invalid Set-Cookie header")
  }
  let name = line[:name_end].to_owned()
  guard line[name_end + 1:].find(";") is Some(value_end) else {
    Cookie(name, line[name_end + 1:].to_owned())
  }
  let value_end = name_end + 1 + value_end
  let value = line[name_end + 1:value_end].to_owned()

  let mut path = None
  let mut expires_raw = None
  let mut max_age = None
  let mut domain = None
  let mut secure = false
  let mut http_only = false
  let extensions = []
  for parsed = value_end + 1 {
    let attr_end = if line[parsed:].find(";") is Some(attr_end) {
      parsed + attr_end
    } else {
      line.length()
    }

    let attr = line[parsed:attr_end].trim()
    if attr.find("=") is Some(attr_name_end) {
      let name = attr[:attr_name_end]
      let value = attr[attr_name_end + 1:]
      match name.to_lower() {
        "path" => path = Some(value.to_owned())
        "expires" => expires_raw = Some(value.to_owned())
        "max-age" => {
          let value = @string.parse_int64(value) catch {
            _ => raise HttpError::InvalidUrl("invalid Set-Cookie header")
          }
          max_age = Some(value)
        }
        "domain" => domain = Some(value.to_owned())
        _ => extensions.push(attr.to_owned())
      }
    } else {
      match attr.to_lower() {
        "secure" => secure = true
        "httponly" => http_only = true
        _ => extensions.push(attr.to_owned())
      }
    }

    if attr_end == line.length() {
      break
    } else {
      continue attr_end + 1
    }
  }
  {
    name,
    value,
    path,
    expires_raw,
    max_age,
    domain,
    secure,
    http_only,
    extensions,
  }
}

///|
fn Cookie::to_header_value(cookie : Cookie) -> String {
  let buf = StringBuilder::new()
  buf.write_string(cookie.name)
  buf.write_char('=')
  buf.write_string(cookie.value)
  if cookie.path is Some(path) {
    buf.write_string("; Path=")
    buf.write_string(path)
  }
  if cookie.expires_raw is Some(expires_raw) {
    buf.write_string("; Expires=")
    buf.write_string(expires_raw)
  }
  if cookie.max_age is Some(max_age) {
    buf.write_string("; Max-Age=")
    buf.write_string(max_age.to_string())
  }
  if cookie.domain is Some(domain) {
    buf.write_string("; Domain=")
    buf.write_string(domain)
  }
  if cookie.secure {
    buf.write_string("; Secure")
  }
  if cookie.http_only {
    buf.write_string("; HttpOnly")
  }
  for ext in cookie.extensions {
    buf.write_string("; ")
    buf.write_string(ext)
  }
  buf.to_string()
}

///|
fn parse_cookies_json(json_str : String) -> Array[Cookie] {
  let parsed = @json.parse(json_str) catch { _ => return [] }
  parse_cookies_value(parsed)
}

///|
fn parse_headers_json(json_str : String) -> Map[String, String] {
  let headers : Map[String, String] = {}
  let parsed = @json.parse(json_str) catch { _ => return headers }
  match parsed {
    Object(map) =>
      map.each(fn(k, v) {
        match v {
          String(s) => headers[normalize_header_key(k)] = s
          _ => ()
        }
      })
    _ => ()
  }
  headers
}

///|
fn has_ascii_upper(value : String) -> Bool {
  for i in 0..<value.length() {
    let c = value[i].to_int()
    if c >= 'A'.to_int() && c <= 'Z'.to_int() {
      return true
    }
  }
  false
}

///|
fn normalize_header_key(value : String) -> String {
  if has_ascii_upper(value) {
    value.to_lower()
  } else {
    value
  }
}

///|
fn parse_cookies_value(value : Json) -> Array[Cookie] {
  let cookies : Array[Cookie] = []
  let parsed = value
  match parsed {
    Array(items) =>
      for item in items {
        match item {
          String(s) =>
            try cookies.push(Cookie::parse(s)) catch {
              _ => ()
            } noraise {
              _ => ()
            }
          _ => ()
        }
      }
    _ => ()
  }
  cookies
}

///|
fn cookies_to_json(cookies : Array[Cookie]) -> String {
  let items : Array[Json] = []
  for cookie in cookies {
    items.push(Json::string(cookie.to_header_value()))
  }
  Json::array(items).stringify()
}

///|
pub(all) struct Addr {
  text : String
  port : Int
}

///|
pub(all) enum RequestMethod {
  Get
  Head
  Post
  Put
  Delete
  Connect
  Options
  Trace
  Patch
} derive(Eq, Compare, Hash, @debug.Debug)

///|
pub impl Show for RequestMethod with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
pub(all) struct Request {
  meth : RequestMethod
  path : String
  headers : Map[String, String]
}

///|
pub suberror HttpError {
  NetworkError(String)
  InvalidUrl(String)
  TimeoutError
  NotSupported
} derive(@debug.Debug)

///|
pub impl Show for HttpError with output(self, logger) {
  logger.write_string(@debug.to_string(self))
}

///|
fn classify_http_error(message : String) -> HttpError {
  let lower = message.to_lower()
  if lower.contains("timeout") {
    TimeoutError
  } else if lower.contains("not supported") || lower.contains("unsupported") {
    NotSupported
  } else {
    NetworkError(message)
  }
}

///|
fn response_has_no_body(code : Int, meth : RequestMethod?) -> Bool {
  match meth {
    Some(Head) => true
    Some(Connect) => code >= 200 && code < 300
    _ =>
      (code >= 100 && code < 200) || code == 204 || code == 205 || code == 304
  }
}

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let entries : Map[String, Json] = {}
  for k, v in headers {
    entries[k] = Json::string(v)
  }
  Json::object(entries).stringify()
}
