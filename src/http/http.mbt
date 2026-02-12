///|
pub(all) struct Response {
  code : Int
  reason : String
  headers : Map[String, String]
}

///|
pub suberror HttpError {
  NetworkError(String)
  InvalidUrl(String)
  TimeoutError
  NotSupported
}

///|
fn headers_to_json(headers : Map[String, String]) -> String {
  let entries : Array[String] = []
  for k, v in headers {
    entries.push("\"" + k + "\":\"" + v + "\"")
  }
  "{" + entries.join(",") + "}"
}
