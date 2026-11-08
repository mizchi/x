///|
fn pipe_fd_to_int(fd : UInt64) -> Int32 {
  let max_int = 2147483647
  if fd > max_int.to_uint64() {
    abort("pipe fd value too large to fit in Int")
  }
  fd.reinterpret_as_int64().to_int()
}

///|
pub impl @process.ProcessInput for PipeRead with fn _process_input_native(self) {
  ignore(self)
  abort("pipe process redirection not supported on wasm target")
}

///|
pub impl @process.ProcessOutput for PipeWrite with fn _process_output_native(
  self,
) {
  ignore(self)
  abort("pipe process redirection not supported on wasm target")
}

///|
pub extend PipeRead with @process.ProcessInput::{
  _release_input_native,
  _process_input_native,
}

///|
pub extend PipeWrite with @process.ProcessOutput::{
  _process_output_native,
  _release_output_native,
}
