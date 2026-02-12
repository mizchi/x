///|
fn extract_host_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    url
  } else {
    url[:path_start].to_string() catch {
      _ => url
    }
  }
}

///|
fn extract_path_from_url(url : String) -> String {
  let start = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut path_start = -1
  for i = start; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = i
      break
    }
  }
  if path_start == -1 {
    "/"
  } else {
    url[path_start:].to_string() catch {
      _ => "/"
    }
  }
}

///|
fn to_response(resp : @async_http.Response) -> Response {
  let headers : Map[String, String] = {}
  for k, v in resp.headers {
    headers[k.to_lower()] = v
  }
  Response::{ code: resp.code, reason: resp.reason, headers }
}

///|
async fn request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, &@io.Data) raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = @async_http.Client::new(host_url, headers~) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  let resp = try {
    match meth {
      "POST" => client.post(path, body)
      "PUT" => client.put(path, body)
      _ => client.get(path)
    }
  } catch {
    err => {
      client.close()
      raise HttpError::NetworkError(err.to_string())
    }
  }
  let body_data : &@io.Data = @io.Reader::read_all(client) catch {
    err => {
      client.close()
      raise HttpError::NetworkError(err.to_string())
    }
  }
  client.close()
  (to_response(resp), body_data)
}

// Streaming API

///|
pub struct Stream {
  inner : @async_http.Client
}

///|
async fn stream_request_internal(
  url : String,
  meth : String,
  headers : Map[String, String],
  body : &@io.Data,
) -> (Response, Stream) raise HttpError {
  let host_url = extract_host_url(url)
  let path = extract_path_from_url(url)
  let client = @async_http.Client::new(host_url, headers~) catch {
    _ => raise HttpError::InvalidUrl(url)
  }
  let resp = try {
    match meth {
      "POST" => client.post(path, body)
      "PUT" => client.put(path, body)
      _ => client.get(path)
    }
  } catch {
    err => {
      client.close()
      raise HttpError::NetworkError(err.to_string())
    }
  }
  (to_response(resp), Stream::{ inner: client })
}

///|
pub async fn get_stream(
  url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  let empty : String = ""
  stream_request_internal(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put_stream(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  stream_request_internal(url, "PUT", headers.unwrap_or({}), body)
}

///|
pub async fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  self.inner.read_some() catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
}

///|
pub async fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  let data : &@io.Data = @io.Reader::read_all(self.inner) catch {
    err => raise HttpError::NetworkError(err.to_string())
  }
  data.binary()
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  self.inner.close()
}

// Non-streaming API

///|
pub async fn get(
  url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  let empty : String = ""
  request_internal(url, "GET", headers.unwrap_or({}), empty)
}

///|
pub async fn post(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal(url, "POST", headers.unwrap_or({}), body)
}

///|
pub async fn put(
  url : String,
  body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  request_internal(url, "PUT", headers.unwrap_or({}), body)
}
