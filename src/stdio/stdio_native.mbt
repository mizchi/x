///|
pub struct Input {
  inner : @async_stdio.Input
}

///|
pub struct Output {
  inner : @async_stdio.Output
}

///|
pub fn Input::fd(self : Input) -> Int {
  self.inner.fd()
}

///|
pub fn Output::fd(self : Output) -> Int {
  self.inner.fd()
}

///|
pub impl @io.Reader for Input with fn _get_internal_buffer(self) {
  @io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @io.Reader for Input with fn _direct_read(self, buf, offset~, max_len~) {
  @io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub impl @process.ProcessInput for Input with fn _process_input_native(self) {
  self.inner
}

///|
pub impl @io.Writer for Output with fn write_once(self, buf, offset~, len~) {
  @io.Writer::write_once(self.inner, buf, offset~, len~)
}

///|
pub impl @process.ProcessOutput for Output with fn _process_output_native(self) {
  self.inner
}

///|
pub let stdin : Input = Input::{ inner: @async_stdio.stdin }

///|
pub let stdout : Output = Output::{ inner: @async_stdio.stdout }

///|
pub let stderr : Output = Output::{ inner: @async_stdio.stderr }
