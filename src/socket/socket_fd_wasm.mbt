///|
fn socket_fd_to_int(fd : UInt64) -> Int {
  let max_int = 2147483647
  let max_uint64 = max_int.to_uint64()
  if fd > max_uint64 {
    abort("socket fd value too large to fit in Int")
  }
  fd.reinterpret_as_int64().to_int()
}
