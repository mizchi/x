///|
pub suberror TlsError {
  TlsError(String)
} derive(ToJson, @debug.Debug)

///|
pub suberror ConnectionClosed derive(ToJson, @debug.Debug)

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for TlsError

///|
pub impl Show for TlsError with output(self, logger) {
  match self {
    TlsError(msg) =>
      logger..write_string("TlsError(")..write_object(msg).write_string(")")
  }
}

///|
#deprecated("`Show` implementation for this type is deprecated, use `Debug` related API, or use `@debug.to_string` instead.")
pub impl Show for ConnectionClosed

///|
pub impl Show for ConnectionClosed with output(_self, logger) {
  logger.write_string("ConnectionClosed")
}

///|
pub(all) enum TrustedRoot {
  NoVerification
  SystemRoot
  CustomPemFile(String)
}

///|
pub(all) enum X509FileType {
  PEM
  ANS1
}

///|
pub fn sha1(src : Bytes) -> Bytes {
  @crypto.sha1(src).unsafe_reinterpret_as_bytes()
}
