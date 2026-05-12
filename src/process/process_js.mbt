///|
priv struct ProcessStart {
  id : Int
  pid : Int
}

///|
pub(open) trait ProcessInput {
  _process_input_js(Self) -> Int
}

///|
pub(open) trait ProcessOutput {
  _process_output_js(Self) -> Int
}

///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
async fn[T] run_js_promise(promise : JsPromise[T]) -> T {
  @js_async.run_promise(fn(_signal) { promise.cast() })
}

///|
fn env_to_arrays(env : Map[String, String]) -> (Array[String], Array[String]) {
  let keys : Array[String] = []
  let values : Array[String] = []
  for k, v in env {
    keys.push(k)
    values.push(v)
  }
  (keys, values)
}

///|
extern "js" fn js_process_init() -> Unit =
  #| () => {
  #|   if (globalThis.__xproc) return;
  #|   globalThis.__xproc = {
  #|     nextId: 1,
  #|     inputs: new Map(),
  #|     outputs: new Map(),
  #|     procs: new Map(),
  #|   };
  #| }

///|
extern "js" fn js_process_redirect_from_file(path : String) -> Int =
  #| (path) => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map() };
  #|   const state = globalThis.__xproc;
  #|   const id = state.nextId++;
  #|   state.inputs.set(id, { type: 'file', path });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_redirect_to_file(
  path : String,
  append : Bool,
  create_mode : Int,
  permission : Int,
) -> Int =
  #| (path, append, createMode, permission) => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map() };
  #|   const state = globalThis.__xproc;
  #|   const id = state.nextId++;
  #|   state.outputs.set(id, { type: 'file', path, append: !!append, createMode: createMode | 0, permission: permission | 0 });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_temp_input() -> Int =
  #| () => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map() };
  #|   const state = globalThis.__xproc;
  #|   const id = state.nextId++;
  #|   state.inputs.set(id, { type: 'temp', chunks: [], closed: false, stream: null });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_temp_output() -> Int =
  #| () => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map() };
  #|   const state = globalThis.__xproc;
  #|   const id = state.nextId++;
  #|   state.outputs.set(id, { type: 'temp', chunks: [], waiters: [], closed: false });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_write_input(
  id : Int,
  data : Bytes,
  offset : Int,
  len : Int,
) -> JsPromise[Int] =
  #| async (id, data, offset, len) => {
  #|   const input = globalThis.__xproc?.inputs?.get(id);
  #|   if (!input) throw new Error('process input not found');
  #|   const chunk = Buffer.from(data).subarray(offset, offset + len);
  #|   if (input.stream) {
  #|     await new Promise((resolve, reject) => input.stream.write(chunk, (err) => err ? reject(err) : resolve()));
  #|   } else {
  #|     input.chunks.push(Buffer.from(chunk));
  #|   }
  #|   return chunk.length | 0;
  #| }

///|
extern "js" fn js_process_close_input(id : Int) -> Unit =
  #| (id) => {
  #|   const input = globalThis.__xproc?.inputs?.get(id);
  #|   if (!input || input.closed) return;
  #|   input.closed = true;
  #|   if (input.stream) {
  #|     try { input.stream.end(); } catch {}
  #|   }
  #| }

///|
extern "js" fn js_process_read_output(
  id : Int,
  max_len : Int,
) -> JsPromise[Bytes] =
  #| async (id, maxLen) => {
  #|   const output = globalThis.__xproc?.outputs?.get(id);
  #|   if (!output) throw new Error('process output not found');
  #|   const take = () => {
  #|     if (output.chunks.length === 0) return null;
  #|     let chunk = output.chunks.shift();
  #|     maxLen = Math.max(0, maxLen | 0);
  #|     if (maxLen > 0 && chunk.length > maxLen) {
  #|       output.chunks.unshift(chunk.subarray(maxLen));
  #|       chunk = chunk.subarray(0, maxLen);
  #|     }
  #|     return new Uint8Array(chunk);
  #|   };
  #|   const immediate = take();
  #|   if (immediate) return immediate;
  #|   if (output.closed) return new Uint8Array(0);
  #|   return await new Promise(resolve => output.waiters.push({ resolve, maxLen }));
  #| }

///|
extern "js" fn js_process_close_output(id : Int) -> Unit =
  #| (id) => {
  #|   const output = globalThis.__xproc?.outputs?.get(id);
  #|   if (!output || output.closed) return;
  #|   output.closed = true;
  #|   for (const waiter of output.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #| }

///|
extern "js" fn js_process_start(
  cmd : String,
  args : Array[String],
  cwd : String?,
  env_keys : Array[String],
  env_values : Array[String],
  inherit_env : Bool,
  stdin_id : Int,
  stdout_id : Int,
  stderr_id : Int,
  inherit_stdio : Bool,
) -> JsPromise[ProcessStart] =
  #| async (cmd, args, cwd, envKeys, envValues, inheritEnv, stdinId, stdoutId, stderrId, inheritStdio) => {
  #|   const { spawn, execFileSync } = await import('node:child_process');
  #|   const fs = await import('node:fs');
  #|   const path = await import('node:path');
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map() };
  #|   const state = globalThis.__xproc;
  #|   let resolvedCmd = cmd;
  #|   if (!inheritEnv && !path.isAbsolute(cmd) && !cmd.includes('/')) {
  #|     try { resolvedCmd = execFileSync('/usr/bin/which', [cmd], { encoding: 'utf8' }).trim(); } catch {}
  #|   }
  #|   const options = { stdio: inheritStdio ? 'inherit' : ['pipe', 'pipe', 'pipe'] };
  #|   if (cwd !== undefined) options.cwd = cwd;
  #|   const extraEnv = {};
  #|   for (let i = 0; i < envKeys.length; i++) extraEnv[envKeys[i]] = envValues[i];
  #|   options.env = inheritEnv ? { ...process.env, ...extraEnv } : extraEnv;
  #|   const child = spawn(resolvedCmd, args, options);
  #|   const id = state.nextId++;
  #|   const proc = { child, code: null, waiters: [] };
  #|   state.procs.set(id, proc);
  #|   child.on('error', err => {
  #|     proc.code = 1;
  #|     for (const waiter of proc.waiters.splice(0)) waiter(1);
  #|   });
  #|   child.on('close', code => {
  #|     proc.code = code ?? 0;
  #|     for (const waiter of proc.waiters.splice(0)) waiter(proc.code);
  #|   });
  #|   if (!inheritStdio) {
  #|     const input = state.inputs.get(stdinId);
  #|     if (!input) {
  #|       child.stdin.end();
  #|     } else if (input.type === 'file') {
  #|       fs.createReadStream(input.path).pipe(child.stdin);
  #|     } else if (input.type === 'temp') {
  #|       input.stream = child.stdin;
  #|       for (const chunk of input.chunks.splice(0)) child.stdin.write(chunk);
  #|       if (input.closed) child.stdin.end();
  #|     }
  #|     const flagFor = (out) => {
  #|       if (out.append) return out.createMode === 4 ? 'ax' : 'a';
  #|       if (out.createMode === 4) return 'wx';
  #|       if (out.createMode === 0) return 'r+';
  #|       return 'w';
  #|     };
  #|     const attachOutput = (stream, outId) => {
  #|       const out = state.outputs.get(outId);
  #|       if (!out) {
  #|         stream.resume();
  #|         return;
  #|       }
  #|       if (out.type === 'file') {
  #|         const ws = fs.createWriteStream(out.path, { flags: flagFor(out), mode: out.permission || 0o644 });
  #|         stream.pipe(ws);
  #|         stream.once('end', () => ws.end());
  #|       } else if (out.type === 'temp') {
  #|         stream.on('data', chunk => {
  #|           const waiter = out.waiters.shift();
  #|           if (waiter) {
  #|             let buf = Buffer.from(chunk);
  #|             const maxLen = Math.max(0, waiter.maxLen | 0);
  #|             if (maxLen > 0 && buf.length > maxLen) {
  #|               out.chunks.unshift(buf.subarray(maxLen));
  #|               buf = buf.subarray(0, maxLen);
  #|             }
  #|             waiter.resolve(new Uint8Array(buf));
  #|           } else {
  #|             out.chunks.push(Buffer.from(chunk));
  #|           }
  #|         });
  #|         stream.once('end', () => {
  #|           out.closed = true;
  #|           for (const waiter of out.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #|         });
  #|       }
  #|     };
  #|     attachOutput(child.stdout, stdoutId);
  #|     attachOutput(child.stderr, stderrId);
  #|   }
  #|   return { id, pid: child.pid | 0 };
  #| }

///|
extern "js" fn js_process_wait(id : Int) -> JsPromise[Int] =
  #| async (id) => {
  #|   const proc = globalThis.__xproc?.procs?.get(id);
  #|   if (!proc) throw new Error('process not found');
  #|   if (proc.code !== null) return proc.code | 0;
  #|   return await new Promise(resolve => proc.waiters.push(resolve));
  #| }

///|
extern "js" fn js_process_try_wait(id : Int) -> Int =
  #| (id) => {
  #|   const proc = globalThis.__xproc?.procs?.get(id);
  #|   if (!proc || proc.code === null) return -2147483648;
  #|   return proc.code | 0;
  #| }

///|
extern "js" fn js_process_cancel(id : Int, hard : Bool) -> Unit =
  #| (id, hard) => {
  #|   const proc = globalThis.__xproc?.procs?.get(id);
  #|   if (!proc) return;
  #|   try { proc.child.kill(hard ? 'SIGKILL' : 'SIGTERM'); } catch {}
  #| }

///|
fn create_mode_to_int(mode : @fs.CreateMode) -> Int {
  match mode {
    OpenExisting => 0
    TruncateExisting => 1
    OpenOrCreate => 2
    CreateOrTruncate => 3
    CreateNew => 4
  }
}

///|
fn process_input_id(input : &ProcessInput?) -> Int {
  match input {
    Some(input) => input._process_input_js()
    None => 0
  }
}

///|
fn process_output_id(output : &ProcessOutput?) -> Int {
  match output {
    Some(output) => output._process_output_js()
    None => 0
  }
}

///|
priv struct JsProcessInput {
  id : Int
}

///|
impl ProcessInput for JsProcessInput with _process_input_js(self) {
  self.id
}

///|
priv struct JsProcessOutput {
  id : Int
}

///|
impl ProcessOutput for JsProcessOutput with _process_output_js(self) {
  self.id
}

///|
pub struct ReadFromProcess {
  id : Int
  read_buf : @async_io.ReaderBuffer
}

///|
pub fn ReadFromProcess::close(self : ReadFromProcess) -> Unit {
  js_process_close_output(self.id)
}

///|
pub impl @async_io.Reader for ReadFromProcess with _get_internal_buffer(self) {
  self.read_buf
}

///|
pub impl @async_io.Reader for ReadFromProcess with _direct_read(
  self,
  buf,
  offset~,
  max_len~,
) {
  let data = run_js_promise(js_process_read_output(self.id, max_len)) catch {
    _ => return 0
  }
  let n = if data.length() < max_len { data.length() } else { max_len }
  buf.blit_from_bytes(offset, data, 0, n)
  n
}

///|
pub struct WriteToProcess {
  id : Int
}

///|
pub fn WriteToProcess::close(self : WriteToProcess) -> Unit {
  js_process_close_input(self.id)
}

///|
pub impl @async_io.Writer for WriteToProcess with write_once(
  self,
  buf,
  offset~,
  len~,
) {
  run_js_promise(js_process_write_input(self.id, buf, offset, len)) catch {
    _ => 0
  }
}

///|
pub fn read_from_process() -> (ReadFromProcess, &ProcessOutput) raise {
  js_process_init()
  let id = js_process_temp_output()
  (
    ReadFromProcess::{ id, read_buf: @async_io.ReaderBuffer::new() },
    JsProcessOutput::{ id, },
  )
}

///|
pub fn write_to_process() -> (&ProcessInput, WriteToProcess) raise {
  js_process_init()
  let id = js_process_temp_input()
  (JsProcessInput::{ id, }, WriteToProcess::{ id, })
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
pub fn redirect_from_file(path : String) -> &ProcessInput {
  js_process_init()
  JsProcessInput::{ id: js_process_redirect_from_file(path) }
}

///|
pub fn redirect_to_file(
  path : String,
  append? : Bool,
  create_mode? : @fs.CreateMode,
  permission? : Int,
  create? : Int,
  truncate? : Bool,
) -> &ProcessOutput {
  ignore((create, truncate))
  js_process_init()
  JsProcessOutput::{
    id: js_process_redirect_to_file(
      path,
      append.unwrap_or(false),
      create_mode_to_int(create_mode.unwrap_or(CreateOrTruncate)),
      permission.unwrap_or(0o644),
    ),
  }
}

///|
async fn start_process(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
  stdin? : &ProcessInput,
  stdout? : &ProcessOutput,
  stderr? : &ProcessOutput,
  inherit_stdio? : Bool = false,
) -> ProcessStart {
  let (env_keys, env_values) = env_to_arrays(extra_env)
  run_js_promise(
    js_process_start(
      cmd.to_owned(),
      Array::from_iter(args.iter().map(fn(s) { s })),
      cwd.map(fn(c) { c.to_owned() }),
      env_keys,
      env_values,
      inherit_env,
      process_input_id(stdin),
      process_output_id(stdout),
      process_output_id(stderr),
      inherit_stdio,
    ),
  )
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
  ignore(cancel_handler)
  let proc = start_process(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
  )
  run_js_promise(js_process_wait(proc.id))
}

///|
async fn run_inherit_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
  extra_env? : Map[String, String] = {},
  inherit_env? : Bool = true,
) -> Int {
  let proc = start_process(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    inherit_stdio=true,
  )
  run_js_promise(js_process_wait(proc.id))
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
  let (stdout_r, stdout_w) = read_from_process()
  let (stderr_r, stderr_w) = read_from_process()
  let code = run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=stdout_w,
    stderr=stderr_w,
    cancel_handler=graceful_cancel(timeout=5000),
  )
  let stdout = stdout_r.read_all()
  let stderr = stderr_r.read_all()
  (code, stdout, stderr)
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
  let (stdout_r, stdout_w) = read_from_process()
  let code = run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=stdout_w,
    stderr?,
    cancel_handler=graceful_cancel(timeout=5000),
  )
  let stdout = stdout_r.read_all()
  (code, stdout)
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
  let (stderr_r, stderr_w) = read_from_process()
  let code = run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr=stderr_w,
    cancel_handler=graceful_cancel(timeout=5000),
  )
  let stderr = stderr_r.read_all()
  (code, stderr)
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
  let (r, w) = read_from_process()
  let code = run_internal(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout=w,
    stderr=w,
    cancel_handler=graceful_cancel(timeout=5000),
  )
  let output = r.read_all()
  (code, output)
}

///|
pub struct Process {
  pid : Int
  priv id : Int
}

///|
pub async fn Process::wait(self : Process) -> Int {
  run_js_promise(js_process_wait(self.id))
}

///|
pub fn Process::try_wait(self : Process) -> Int? raise {
  let code = js_process_try_wait(self.id)
  if code == -2147483648 {
    None
  } else {
    Some(code)
  }
}

///|
pub fn Process::cancel(self : Process) -> Unit {
  js_process_cancel(self.id, false)
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
) -> Process {
  ignore(cancel_handler)
  let start = start_process(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
  )
  let id = start.id
  ignore(group.spawn(no_wait?, () => run_js_promise(js_process_wait(id))))
  Process::{ pid: start.pid, id }
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
  let start = start_process(
    cmd,
    args,
    cwd?,
    extra_env~,
    inherit_env~,
    stdin?,
    stdout?,
    stderr?,
  )
  start.pid
}

///|
pub async fn wait_pid(_pid : Int) -> Int {
  abort("wait_pid is not supported on js target")
}
