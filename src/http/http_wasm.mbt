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
