///|
fn to_async_create_mode(mode : @fs.CreateMode) -> @async_fs.CreateMode {
  match mode {
    OpenExisting => @async_fs.OpenExisting
    TruncateExisting => @async_fs.TruncateExisting
    OpenOrCreate => @async_fs.OpenOrCreate
    CreateOrTruncate => @async_fs.CreateOrTruncate
    CreateNew => @async_fs.CreateNew
  }
}

///|
fn to_async_cancel(
  handler : CancellationHandler,
) -> @async_process.CancellationHandler {
  match handler.kind {
    Graceful(timeout, signal) =>
      @async_process.graceful_cancel(
        timeout~,
        signal?=signal.map(signal_to_async),
      )
    Hard => @async_process.hard_cancel()
  }
}

///|
fn signal_to_async(signal : @signal.Signal) -> @async_signal.Signal {
  match signal {
    SIGINT => @async_signal.SIGINT
    SIGTERM => @async_signal.SIGTERM
    SIGHUP => @async_signal.SIGHUP
    SIGBREAK => @async_signal.SIGBREAK
  }
}

///|
pub(open) trait ProcessInput {
  fn _process_input_native(Self) -> &@async_process.ProcessInput
}

///|
pub(open) trait ProcessOutput {
  fn _process_output_native(Self) -> &@async_process.ProcessOutput
}

///|
priv struct NativeProcessInput {
  inner : &@async_process.ProcessInput
}

///|
impl ProcessInput for NativeProcessInput with fn _process_input_native(self) {
  self.inner
}

///|
priv struct NativeProcessOutput {
  inner : &@async_process.ProcessOutput
}

///|
impl ProcessOutput for NativeProcessOutput with fn _process_output_native(self) {
  self.inner
}

///|
pub struct ReadFromProcess {
  priv inner : @async_process.ReadFromProcess
}

///|
pub fn ReadFromProcess::close(self : ReadFromProcess) -> Unit {
  self.inner.close()
}

///|
pub impl @async_io.Reader for ReadFromProcess with fn _get_internal_buffer(self) {
  @async_io.Reader::_get_internal_buffer(self.inner)
}

///|
pub impl @async_io.Reader for ReadFromProcess with fn _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  @async_io.Reader::_direct_read(self.inner, buf, offset~, max_len~)
}

///|
pub struct WriteToProcess {
  priv inner : @async_process.WriteToProcess
}

///|
pub fn WriteToProcess::close(self : WriteToProcess) -> Unit {
  self.inner.close()
}

///|
pub impl @async_io.Writer for WriteToProcess with fn write_once(
  self,
  buf,
  offset~,
  len~,
) {
  @async_io.Writer::write_once(self.inner, buf, offset~, len~)
}

///|
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  let (r, w) = @async_process.read_from_process()
  (ReadFromProcess::{ inner: r }, NativeProcessOutput::{ inner: w })
}

///|
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  let (r, w) = @async_process.write_to_process()
  (NativeProcessInput::{ inner: r }, WriteToProcess::{ inner: w })
}

///|
pub async fn run(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
) -> Int {
  run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cancel_handler~,
  )
}

///|
pub async fn run_inherit(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  cwd? : StringView,
) -> Int {
  run_inherit_internal(cmd, args, cwd?, extra_env~, inherit_env~)
}

///|
pub async fn collect_output(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  collect_output_internal(cmd, args, cwd?, extra_env~, inherit_env~, stdin?)
}

///|
pub async fn collect_stdout(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  collect_stdout_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stderr?,
  )
}

///|
pub async fn collect_stderr(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  collect_stderr_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
  )
}

///|
pub async fn collect_output_merged(
  cmd : StringView,
  args : Array[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  cwd? : StringView,
) -> (Int, &@async_io.Data) {
  collect_output_merged_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
  )
}

///|
pub async fn redirect_from_file(path : String) -> &ProcessInput {
  NativeProcessInput::{ inner: @async_process.redirect_from_file(path) }
}

///|
pub async fn redirect_to_file(
  path : String,
  append? : Bool,
  create_mode? : @fs.CreateMode,
  permission? : Int,
  create? : Int,
  truncate? : Bool,
) -> &ProcessOutput {
  let create_mode = to_async_create_mode(
    match create_mode {
      Some(mode) => mode
      None =>
        match (create is Some(_), truncate.unwrap_or(false)) {
          (true, true) => @fs.CreateOrTruncate
          (true, false) => @fs.OpenOrCreate
          (false, true) => @fs.TruncateExisting
          (false, false) => @fs.OpenExisting
        }
    },
  )
  let permission = match permission {
    Some(p) => p
    None =>
      match create {
        Some(p) => p
        None => 0o644
      }
  }
  @async_process.redirect_to_file(path, append?, create_mode~, permission~)
  |> fn(inner) { NativeProcessOutput::{ inner, } }
}

///|
async fn run_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cancel_handler~ : CancellationHandler,
) -> Int {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  @async_process.run(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    cancel_handler=to_async_cancel(cancel_handler),
  )
}

///|
async fn run_inherit_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> Int {
  @async_process.run(cmd, args, extra_env~, inherit_env~, cwd?)
}

///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  @async_process.collect_output(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    cwd?,
  )
}

///|
async fn collect_stdout_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stderr? : &ProcessOutput,
) -> (Int, &@async_io.Data) {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  @async_process.collect_stdout(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stderr?,
    cwd?,
  )
}

///|
async fn collect_stderr_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
) -> (Int, &@async_io.Data) {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  @async_process.collect_stderr(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    cwd?,
  )
}

///|
async fn collect_output_merged_internal(
  cmd : StringView,
  args : Array[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
) -> (Int, &@async_io.Data) {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  @async_process.collect_output_merged(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    cwd?,
  )
}

///|
pub struct Process {
  pid : Int
  priv inner : @async_process.Process
}

///|
pub async fn Process::wait(self : Process) -> Int {
  self.inner.wait()
}

///|
pub fn Process::try_wait(self : Process) -> Int? raise {
  self.inner.try_wait()
}

///|
pub fn Process::cancel(self : Process) -> Unit {
  self.inner.cancel()
}

///|
/// Best-effort: move `pid` into its own process group via
/// `setpgid(pid, pid)`. Returns 0 on success (or when the child has
/// already exec'd and set its own pgid, which is treated as soft
/// success); a non-zero errno otherwise. The race window between the
/// async spawn helper's posix_spawn and this call is the reason the
/// `new_process_group` flag on `spawn` is documented as best-effort —
/// the kernel-level fix is `POSIX_SPAWN_SETPGROUP`, which needs
/// upstream moonbitlang/async to thread through.
extern "C" fn process_setpgid_self_ffi(pid : Int) -> Int = "mizchi_x_process_setpgid_self"

///|
/// `kill(2)` raw wrapper. Returns 0 on success, an errno otherwise.
extern "C" fn process_kill_ffi(pid : Int, signal : Int) -> Int = "mizchi_x_process_kill"

///|
/// Send a signal to `pid`. Mirrors `kill(2)` — pass a negative `pid`
/// to target the process group whose pgid equals `-pid`. Silently
/// drops the errno; use the raw FFI if you need it.
pub fn kill(pid : Int, signal : @signal.Signal) -> Unit {
  ignore(process_kill_ffi(pid, signal.to_int()))
}

///|
/// Send a signal to every process whose pgid equals this process's
/// pid. Effective only when the spawn was set up as a process-group
/// leader — pair with `spawn(..., new_process_group=true)`. When the
/// leader-set raced and lost, the call still sends `signal` to a
/// process group containing this single pid, so direct children
/// inheriting the parent's pgid are NOT hit; the caller must fall
/// back to per-pid signalling or `pkill -P` for the subtree.
pub fn Process::kill_tree(self : Process, signal : @signal.Signal) -> Unit {
  ignore(process_kill_ffi(-self.pid, signal.to_int()))
}

///|
pub async fn[X] spawn(
  group : @async.TaskGroup[X],
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
  cancel_handler? : CancellationHandler = graceful_cancel(timeout=5000),
  no_wait? : Bool,
  new_process_group? : Bool = false,
) -> Process {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  let inner = @async_process.spawn(
    group,
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
    cancel_handler=to_async_cancel(cancel_handler),
    no_wait?,
  )
  // PKF-5: move the freshly-spawned child into its own process group
  // so a later `kill_tree` can take down its descendants. The race
  // window (child runs with the parent's pgid until this call lands)
  // is sub-millisecond on posix_spawn paths; the FFI silently absorbs
  // the EACCES / EPERM that occur when the child has already exec'd
  // and set its own pgid.
  if new_process_group {
    ignore(process_setpgid_self_ffi(inner.pid))
  }
  Process::{ pid: inner.pid, inner }
}

///|
pub async fn spawn_orphan(
  cmd : StringView,
  args : ArrayView[String],
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  cwd? : StringView,
) -> Int {
  let stdin = stdin.map(fn(input) { input._process_input_native() })
  let stdout = stdout.map(fn(output) { output._process_output_native() })
  let stderr = stderr.map(fn(output) { output._process_output_native() })
  @async_process.spawn_orphan(
    cmd,
    args,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
    cwd?,
  )
}

///|
pub async fn wait_pid(pid : Int) -> Int {
  @async_process.wait_pid(pid)
}
