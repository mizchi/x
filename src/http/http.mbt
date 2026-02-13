///|
pub(all) struct Response {
  code : Int
  reason : String
  headers : Map[String, String]
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
} derive(Show, Eq, Compare, Hash)

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
} derive(Show)

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let entries : Map[String, Json] = {}
  for k, v in headers {
    entries[k] = Json::string(v)
  }
  Json::object(entries).stringify()
}
