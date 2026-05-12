///|
pub struct RawFd {
  fd : Int
  priv mut closed : Bool
}

///|
#borrow(buf)
extern "C" fn raw_fd_read_ffi(
  fd : Int,
  buf : FixedArray[Byte],
  offset~ : Int,
  len~ : Int,
) -> Int = "mizchi_x_raw_fd_read"

///|
#borrow(buf)
extern "C" fn raw_fd_write_ffi(
  fd : Int,
  buf : Bytes,
  offset~ : Int,
  len~ : Int,
) -> Int = "mizchi_x_raw_fd_write"

///|
extern "C" fn raw_fd_close_ffi(fd : Int) -> Int = "mizchi_x_raw_fd_close"

///|
#alias(new, deprecated)
pub async fn RawFd::RawFd(fd : Int) -> RawFd {
  { fd, closed: false }
}

///|
pub fn RawFd::close(self : RawFd) -> Unit {
  if !self.closed {
    ignore(raw_fd_close_ffi(self.fd))
    self.closed = true
  }
}

///|
pub async fn RawFd::read(
  self : RawFd,
  buf : FixedArray[Byte],
  offset? : Int = 0,
  max_len? : Int = buf.length() - offset,
) -> Int {
  if self.closed || max_len <= 0 {
    0
  } else {
    let ret = raw_fd_read_ffi(self.fd, buf, offset~, len=max_len)
    if ret < 0 {
      0
    } else {
      ret
    }
  }
}

///|
pub async fn RawFd::write(
  self : RawFd,
  buf : Bytes,
  offset? : Int = 0,
  len? : Int = buf.length() - offset,
) -> Int {
  if self.closed || len <= 0 {
    0
  } else {
    let ret = raw_fd_write_ffi(self.fd, buf, offset~, len~)
    if ret < 0 {
      0
    } else {
      ret
    }
  }
}
