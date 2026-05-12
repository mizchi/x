///|
pub struct RawFd {
  fd : Int
}

///|
#alias(new, deprecated)
pub async fn RawFd::RawFd(fd : Int) -> RawFd {
  ignore(fd)
  abort("raw_fd is not supported on wasm-gc target")
}

///|
pub fn RawFd::close(self : RawFd) -> Unit {
  ignore(self)
}

///|
pub async fn RawFd::read(
  self : RawFd,
  buf : FixedArray[Byte],
  offset? : Int = 0,
  max_len? : Int = buf.length() - offset,
) -> Int {
  ignore((self, buf, offset, max_len))
  abort("raw_fd is not supported on wasm-gc target")
}

///|
pub async fn RawFd::write(
  self : RawFd,
  buf : Bytes,
  offset? : Int = 0,
  len? : Int = buf.length() - offset,
) -> Int {
  ignore((self, buf, offset, len))
  abort("raw_fd is not supported on wasm-gc target")
}
