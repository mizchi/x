///|
pub struct Stream {}

///|
pub fn get_stream(
  _url : String,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

///|
pub fn post_stream(
  _url : String,
  _body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

///|
pub fn put_stream(
  _url : String,
  _body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, Stream) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

///|
pub fn Stream::read_some(self : Stream) -> Bytes? raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Stream::read_all(self : Stream) -> Bytes raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Stream::close(self : Stream) -> Unit {
  ignore(self)
  abort("Stream::close not supported on wasm target")
}

///|
pub fn get(
  _url : String,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

///|
pub fn post(
  _url : String,
  _body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

///|
pub fn put(
  _url : String,
  _body : &@io.Data,
  headers? : Map[String, String],
) -> (Response, &@io.Data) raise HttpError {
  ignore(headers)
  raise HttpError::NotSupported
}

// Server API

///|
pub struct Server {}

///|
pub struct ServerConnection {}

///|
pub fn Server::new(
  host? : String,
  port? : Int,
  headers? : Map[String, String],
  dual_stack? : Bool,
  reuse_addr? : Bool,
  max_request_body_bytes? : Int,
  request_timeout_ms? : Int,
  keep_alive_timeout_ms? : Int,
  headers_timeout_ms? : Int,
  accept_queue_limit? : Int,
) -> Server raise HttpError {
  ignore(host)
  ignore(port)
  ignore(headers)
  ignore(dual_stack)
  ignore(reuse_addr)
  ignore(max_request_body_bytes)
  ignore(request_timeout_ms)
  ignore(keep_alive_timeout_ms)
  ignore(headers_timeout_ms)
  ignore(accept_queue_limit)
  raise HttpError::NotSupported
}

///|
pub fn Server::port(self : Server) -> Int {
  ignore(self)
  0
}

///|
pub fn Server::addr(self : Server) -> Addr {
  ignore(self)
  abort("Server::addr not supported on wasm target")
}

///|
pub fn Server::close(self : Server) -> Unit {
  ignore(self)
}

///|
pub fn Server::close_graceful(
  self : Server,
  timeout_ms? : Int,
) -> Unit raise HttpError {
  ignore(self)
  ignore(timeout_ms)
  raise HttpError::NotSupported
}

///|
pub fn Server::accept(
  self : Server,
) -> (ServerConnection, Addr) raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn Server::run_forever(
  self : Server,
  _f : async (Request, &@io.Reader, ServerConnection) -> Unit,
  allow_failure? : Bool,
  max_connections? : Int,
) -> Unit raise HttpError {
  ignore(self)
  ignore(allow_failure)
  ignore(max_connections)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::close(self : ServerConnection) -> Unit {
  ignore(self)
}

///|
pub fn ServerConnection::client_addr(self : ServerConnection) -> Addr {
  ignore(self)
  abort("ServerConnection::client_addr not supported on wasm target")
}

///|
pub fn ServerConnection::read_request(
  self : ServerConnection,
) -> Request raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::skip_request_body(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::send_response(
  self : ServerConnection,
  _code : Int,
  _reason : String,
  extra_headers? : Map[String, String],
) -> Unit raise HttpError {
  ignore(self)
  ignore(extra_headers)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::flush(self : ServerConnection) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::end_response(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub fn ServerConnection::enter_passthrough_mode(
  self : ServerConnection,
) -> Unit raise HttpError {
  ignore(self)
  raise HttpError::NotSupported
}

///|
pub impl @io.Reader for ServerConnection with _get_internal_buffer(self) {
  ignore(self)
  abort("ServerConnection reader not supported on wasm target")
}

///|
pub impl @io.Reader for ServerConnection with _direct_read(
  self,
  _buf,
  offset~,
  max_len~,
) {
  ignore(self)
  ignore(offset)
  ignore(max_len)
  raise HttpError::NotSupported
}

///|
pub impl @io.Writer for ServerConnection with write_once(
  self,
  _buf,
  offset~,
  len~,
) {
  ignore(self)
  ignore(offset)
  ignore(len)
  raise HttpError::NotSupported
}
