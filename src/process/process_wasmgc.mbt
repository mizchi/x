///|
pub(open) trait ProcessInput {
  _process_input_wasmgc(Self) -> Unit
}

///|
pub(open) trait ProcessOutput {
  _process_output_wasmgc(Self) -> Unit
}

///|
pub struct ReadFromProcess {
  read_buf : @async_io.ReaderBuffer
}

///|
pub fn ReadFromProcess::close(_self : ReadFromProcess) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
pub impl @async_io.Reader for ReadFromProcess with _get_internal_buffer(self) {
  self.read_buf
}

///|
pub impl @async_io.Reader for ReadFromProcess with _direct_read(
  _self,
  _buf,
  offset~ : Int,
  max_len~ : Int,
) {
  ignore((offset, max_len))
  abort("process is not supported on wasm-gc target")
}

///|
pub struct WriteToProcess {}

///|
pub fn WriteToProcess::close(_self : WriteToProcess) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
pub impl @async_io.Writer for WriteToProcess with write_once(
  _self,
  _buf,
  offset~ : Int,
  len~ : Int,
) {
  ignore((offset, len))
  abort("process is not supported on wasm-gc target")
}

///|
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn run(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
) -> Int {
  ignore((cwd, extra_env, inherit_env, stdin, stdout, stderr, cancel_handler))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn run_inherit(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  cwd? : StringView,
) -> Int {
  ignore((cwd, extra_env, inherit_env))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_output(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env, stdin))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_stdout(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env, stdin, stderr))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_stderr(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env, stdin, stdout))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn collect_output_merged(
  _cmd : StringView,
  _args : Array[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  ignore((cwd, extra_env, inherit_env, stdin))
  abort("process is not supported on wasm-gc target")
}

///|
pub fn redirect_from_file(_path : String) -> &ProcessInput {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn redirect_to_file(
  _path : String,
  append? : Bool,
  create_mode? : @fs.CreateMode,
  permission? : Int,
  create? : Int,
  truncate? : Bool,
) -> &ProcessOutput {
  ignore((append, create_mode, permission, create, truncate))
  abort("process is not supported on wasm-gc target")
}

///|
pub struct Process {
  pid : Int
}

///|
pub async fn Process::wait(_self : Process) -> Int {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn Process::try_wait(_self : Process) -> Int? raise {
  abort("process is not supported on wasm-gc target")
}

///|
pub fn Process::cancel(_self : Process) -> Unit {
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn[X] spawn(
  _group : @async.TaskGroup[X],
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
) -> Process {
  ignore(
    (
      cwd, extra_env, inherit_env, stdin, stdout, stderr, cancel_handler, no_wait,
    ),
  )
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn spawn_orphan(
  _cmd : StringView,
  _args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> Int {
  ignore((cwd, extra_env, inherit_env, stdin, stdout, stderr))
  abort("process is not supported on wasm-gc target")
}

///|
pub async fn wait_pid(_pid : Int) -> Int {
  abort("process is not supported on wasm-gc target")
}
