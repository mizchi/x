///|
fn pipe_fd_to_int(fd : UInt64) -> Int {
  let max_int = 2147483647
  if fd > max_int.to_uint64() {
    abort("pipe fd value too large to fit in Int")
  }
  fd.reinterpret_as_int64().to_int()
}
