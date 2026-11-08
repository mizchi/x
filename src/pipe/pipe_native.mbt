///|
pub struct PipeRead {
  priv read_controller : @io.BinaryReaderController
  inner : @async_pipe.PipeRead
}

///|
pub struct PipeWrite {
  priv write_controller : @io.BinaryWriterController
  inner : @async_pipe.PipeWrite
}

///|
pub fn pipe() -> (PipeRead, PipeWrite) raise {
  let (r, w) = @async_pipe.pipe()
  (
    PipeRead::{ read_controller: @io.BinaryReaderController(), inner: r, },
    PipeWrite::{ write_controller: @io.BinaryWriterController(), inner: w, },
  )
}

///|
pub fn PipeRead::close(self : PipeRead) -> Unit {
  self.inner.close()
}

///|
pub fn PipeWrite::close(self : PipeWrite) -> Unit {
  self.inner.close()
}

///|
pub fn PipeRead::fd(self : PipeRead) -> Int32 {
  let fd = self.inner.fd()
  pipe_fd_to_int(fd)
}

///|
pub fn PipeWrite::fd(self : PipeWrite) -> Int32 {
  let fd = self.inner.fd()
  pipe_fd_to_int(fd)
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn get_controller(self) {
  self.read_controller
}

///|
impl @io.BinaryReaderImpl for PipeRead with fn raw_read_impl(
  self,
  buf,
  offset~,
  max_len~,
) {
  self.inner.read_into(buf, offset~, max_len~)
}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn raw_write_impl(
  self,
  buf,
  offset~,
  len~,
) {
  self.inner.write(buf[offset:offset + len])
  len
}

///|
pub impl @io.BinaryReader for PipeRead

///|
pub extend PipeRead with @io.BinaryReader::{
  read_into,
  read_at_least,
  peek,
  peek_at_least,
  read_exactly,
  drop_exactly,
  peek_exactly,
  drop_all,
  peek_until,
}

///|
pub impl @io.BinaryWriter for PipeWrite

///|
pub extend PipeWrite with @io.BinaryWriter::{write_reader}

///|
impl @io.BinaryWriterImpl for PipeWrite with fn get_controller(self) {
  self.write_controller
}
