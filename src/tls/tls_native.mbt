///|
pub struct Tls {
  priv inner : @async_tls.Tls
}

///|
fn to_async_trust(trust : TrustedRoot) -> @async_tls.TrustedRoot {
  match trust {
    NoVerification => @async_tls.NoVerification
    SystemRoot => @async_tls.SystemRoot
    CustomPemFile(file) => @async_tls.CustomPemFile(file)
  }
}

///|
fn to_async_file_type(t : X509FileType) -> @async_tls.X509FileType {
  match t {
    PEM => @async_tls.PEM
    ANS1 => @async_tls.ANS1
  }
}

///|
fn[T] raise_tls_error(err : Error) -> T raise {
  let message = err.to_string()
  if message == "ConnectionClosed" {
    raise ConnectionClosed
  }
  raise TlsError(message)
}

///|
pub fn rand_bytes(num : Int) -> Bytes raise {
  @async_tls.rand_bytes(num) catch {
    err => raise_tls_error(err)
  }
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[Inner : @io.Reader + @io.Writer] Tls::client(
  inner : Inner,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  let trust = match trust {
    Some(trust) => trust
    None => if verify { SystemRoot } else { NoVerification }
  }
  let inner = @async_tls.Tls::client(
    inner,
    host?,
    sni~,
    trust=to_async_trust(trust),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{ inner, }
}

///|
#label_migration(verify, fill=false, msg="use `trust` instead")
pub async fn[R : @io.Reader, W : @io.Writer] Tls::client_from_pair(
  reader : R,
  writer : W,
  verify? : Bool = true,
  host? : String,
  sni? : Bool = true,
  trust? : TrustedRoot,
) -> Tls {
  let trust = match trust {
    Some(trust) => trust
    None => if verify { SystemRoot } else { NoVerification }
  }
  let inner = @async_tls.Tls::client_from_pair(
    reader,
    writer,
    host?,
    sni~,
    trust=to_async_trust(trust),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{ inner, }
}

///|
pub async fn[Inner : @io.Reader + @io.Writer] Tls::server(
  inner : Inner,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  let inner = @async_tls.Tls::server(
    inner,
    private_key_file~,
    private_key_type=to_async_file_type(private_key_type),
    certificate_file~,
    certificate_type=to_async_file_type(certificate_type),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{ inner, }
}

///|
pub async fn[R : @io.Reader, W : @io.Writer] Tls::server_from_pair(
  reader : R,
  writer : W,
  private_key_file~ : String,
  private_key_type~ : X509FileType,
  certificate_file~ : String,
  certificate_type~ : X509FileType,
) -> Tls {
  let inner = @async_tls.Tls::server_from_pair(
    reader,
    writer,
    private_key_file~,
    private_key_type=to_async_file_type(private_key_type),
    certificate_file~,
    certificate_type=to_async_file_type(certificate_type),
  ) catch {
    err => raise_tls_error(err)
  }
  Tls::{ inner, }
}

///|
pub fn Tls::close(self : Tls) -> Unit {
  self.inner.close()
}

///|
pub async fn Tls::shutdown(self : Tls) -> Unit {
  self.inner.shutdown() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::get_peer_certificate(self : Tls) -> Bytes? raise {
  self.inner.get_peer_certificate() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::unique_channel_binding(self : Tls) -> Bytes raise {
  self.inner.unique_channel_binding() catch {
    err => raise_tls_error(err)
  }
}

///|
pub fn Tls::server_endpoint_channel_binding(self : Tls) -> Bytes raise {
  self.inner.server_endpoint_channel_binding() catch {
    err => raise_tls_error(err)
  }
}

///|
pub impl @io.Reader for Tls with _get_internal_buffer(self) {
  self.inner._get_internal_buffer()
}

///|
pub impl @io.Reader for Tls with _direct_read(self, buf, offset~, max_len~) {
  self.inner._direct_read(buf, offset~, max_len~) catch {
    err => raise_tls_error(err)
  }
}

///|
pub impl @io.Writer for Tls with write_once(self, buf, offset~, len~) {
  self.inner.write_once(buf, offset~, len~) catch {
    err => raise_tls_error(err)
  }
}
