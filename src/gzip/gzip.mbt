///|
pub struct Decoder[R] {
  priv inner : @async_gzip.Decoder[R]
}

///|
#alias(new, deprecated)
pub fn[R : @io.Reader] Decoder::Decoder(inner : R) -> Decoder[R] {
  { inner: @async_gzip.Decoder(inner) }
}

///|
pub impl[R : @io.Reader] @io.Reader for Decoder[R] with _get_internal_buffer(
  self,
) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl[R : @io.Reader] @io.Reader for Decoder[R] with _direct_read(
  self,
  dst,
  offset~,
  max_len~,
) {
  @io.Reader::_direct_read(self.inner, dst, offset~, max_len~)
}

///|
pub struct Encoder[W] {
  priv inner : @async_gzip.Encoder[W]
}

///|
#alias(new, deprecated)
pub fn[W] Encoder::Encoder(
  inner : W,
  mtime? : UInt = 0U,
  extra_flags? : Byte = b'\x00',
  operating_system? : Byte = b'\xff',
) -> Encoder[W] {
  { inner: @async_gzip.Encoder(inner, mtime~, extra_flags~, operating_system~) }
}

///|
pub async fn[W : @io.Writer] Encoder::flush(self : Encoder[W]) -> Unit {
  self.inner.flush()
}

///|
pub async fn[W : @io.Writer] Encoder::end(self : Encoder[W]) -> Unit {
  self.inner.end()
}

///|
pub impl[W : @io.Writer] @io.Writer for Encoder[W] with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}
