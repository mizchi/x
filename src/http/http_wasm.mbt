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
