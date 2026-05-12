///|
pub struct Tls {}

///|
pub fn rand_bytes(_num : Int) -> Bytes raise {
  raise TlsError("tls rand_bytes is not supported on this target")
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[Inner : @io.Reader + @io.Writer] Tls::client(
  _inner : Inner,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  ignore((verify, host, sni, trust))
  abort("tls is not supported on this target")
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[R : @io.Reader, W : @io.Writer] Tls::client_from_pair(
  _reader : R,
  _writer : W,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  ignore((verify, host, sni, trust))
  abort("tls is not supported on this target")
}

///|
pub async fn[Inner : @io.Reader + @io.Writer] Tls::server(
  _inner : Inner,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  ignore(
    (private_key_file, private_key_type, certificate_file, certificate_type),
  )
  abort("tls is not supported on this target")
}

///|
pub async fn[R : @io.Reader, W : @io.Writer] Tls::server_from_pair(
  _reader : R,
  _writer : W,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  ignore(
    (private_key_file, private_key_type, certificate_file, certificate_type),
  )
  abort("tls is not supported on this target")
}

///|
pub fn Tls::close(_self : Tls) -> Unit {
  ()
}

///|
pub async fn Tls::shutdown(_self : Tls) -> Unit {
  ()
}

///|
pub fn Tls::get_peer_certificate(_self : Tls) -> Bytes? raise {
  raise TlsError("tls is not supported on this target")
}

///|
pub fn Tls::unique_channel_binding(_self : Tls) -> Bytes raise {
  raise TlsError("tls is not supported on this target")
}

///|
pub fn Tls::server_endpoint_channel_binding(_self : Tls) -> Bytes raise {
  raise TlsError("tls is not supported on this target")
}

///|
pub impl @io.Reader for Tls with _get_internal_buffer(_self) {
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for Tls with _direct_read(_self, _buf, offset~, max_len~) {
  ignore((offset, max_len))
  abort("tls is not supported on this target")
}

///|
pub impl @io.Writer for Tls with write_once(_self, _buf, offset~, len~) {
  ignore((offset, len))
  abort("tls is not supported on this target")
}
