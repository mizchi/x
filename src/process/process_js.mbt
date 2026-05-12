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
  #|     pids: new Map(),
  #|   };
  #| }

///|
extern "js" fn js_process_redirect_from_file(path : String) -> Int =
  #| (path) => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map(), pids: new Map() };
  #|   const state = globalThis.__xproc;
  #|   state.pids ??= new Map();
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
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map(), pids: new Map() };
  #|   const state = globalThis.__xproc;
  #|   state.pids ??= new Map();
  #|   const id = state.nextId++;
  #|   state.outputs.set(id, { type: 'file', path, append: !!append, createMode: createMode | 0, permission: permission | 0 });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_temp_input() -> Int =
  #| () => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map(), pids: new Map() };
  #|   const state = globalThis.__xproc;
  #|   state.pids ??= new Map();
  #|   const id = state.nextId++;
  #|   state.inputs.set(id, { type: 'temp', chunks: [], closed: false, stream: null });
  #|   return id | 0;
  #| }

///|
extern "js" fn js_process_temp_output() -> Int =
  #| () => {
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map(), pids: new Map() };
  #|   const state = globalThis.__xproc;
  #|   state.pids ??= new Map();
  #|   const id = state.nextId++;
  #|   state.outputs.set(id, { type: 'temp', chunks: [], waiters: [], closed: false, open: 0 });
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
  #|   output.open = 0;
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
  #|   globalThis.__xproc ??= { nextId: 1, inputs: new Map(), outputs: new Map(), procs: new Map(), pids: new Map() };
  #|   const state = globalThis.__xproc;
  #|   state.pids ??= new Map();
  #|   let resolvedCmd = cmd;
  #|   if (!inheritEnv && !path.isAbsolute(cmd) && !cmd.includes('/')) {
  #|     try { resolvedCmd = execFileSync('/usr/bin/which', [cmd], { encoding: 'utf8' }).trim(); } catch {}
  #|   }
  #|   const outputSpec = (id) => {
  #|     if (id === -1) return process.stdout;
  #|     if (id === -2) return process.stderr;
  #|     return 'pipe';
  #|   };
  #|   const stdio = inheritStdio
  #|     ? 'inherit'
  #|     : [stdinId === -1 ? process.stdin : 'pipe', outputSpec(stdoutId), outputSpec(stderrId)];
  #|   const options = { stdio };
  #|   if (cwd !== undefined) options.cwd = cwd;
  #|   const extraEnv = {};
  #|   for (let i = 0; i < envKeys.length; i++) extraEnv[envKeys[i]] = envValues[i];
  #|   options.env = inheritEnv ? { ...process.env, ...extraEnv } : extraEnv;
  #|   const child = spawn(resolvedCmd, args, options);
  #|   const id = state.nextId++;
  #|   const proc = { child, pid: Number(child.pid || 0) | 0, code: null, waiters: [] };
  #|   state.procs.set(id, proc);
  #|   if (proc.pid > 0) state.pids.set(proc.pid, id);
  #|   const finish = (code) => {
  #|     if (proc.code !== null) return;
  #|     proc.code = Number(code ?? 0) | 0;
  #|     for (const waiter of proc.waiters.splice(0)) waiter(proc.code);
  #|   };
  #|   child.on('error', _err => finish(1));
  #|   child.on('close', code => finish(code));
  #|   if (!inheritStdio) {
  #|     const input = state.inputs.get(stdinId);
  #|     if (!child.stdin) {
  #|       // stdin is inherited from the parent process
  #|     } else if (!input) {
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
  #|         out.open = (out.open || 0) + 1;
  #|         stream.on('data', chunk => {
  #|           if (out.closed) return;
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
  #|         let finished = false;
  #|         const finish = () => {
  #|           if (finished) return;
  #|           finished = true;
  #|           out.open = Math.max(0, (out.open || 0) - 1);
  #|           if (out.open === 0 && !out.closed) {
  #|             out.closed = true;
  #|             for (const waiter of out.waiters.splice(0)) waiter.resolve(new Uint8Array(0));
  #|           }
  #|         };
  #|         stream.once('end', finish);
  #|         stream.once('close', finish);
  #|         stream.once('error', finish);
  #|       }
  #|     };
  #|     if (child.stdout) attachOutput(child.stdout, stdoutId);
  #|     if (child.stderr) attachOutput(child.stderr, stderrId);
  #|   }
  #|   return { id, pid: proc.pid };
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
extern "js" fn js_process_wait_pid(pid : Int) -> JsPromise[Int] =
  #| async (pid) => {
  #|   const state = globalThis.__xproc;
  #|   const id = state?.pids?.get(pid | 0);
  #|   const proc = id ? state.procs.get(id) : null;
  #|   if (!proc) throw new Error('process not found');
  #|   if (proc.code !== null) return proc.code | 0;
  #|   return await new Promise(resolve => proc.waiters.push(resolve));
  #| }

///|
extern "js" fn js_process_wait_with_cancel(
  id : Int,
  hard : Bool,
  timeout_ms : Int,
  signal_name : String,
  abort_signal : @js_async.AbortSignal,
) -> JsPromise[Int] =
  #| async (id, hard, timeoutMs, signalName, abortSignal) => {
  #|   const proc = globalThis.__xproc?.procs?.get(id);
  #|   if (!proc) throw new Error('process not found');
  #|   if (proc.code !== null) return proc.code | 0;
  #|   let hardTimer = null;
  #|   const wait = new Promise(resolve => proc.waiters.push(resolve));
  #|   const cleanup = () => {
  #|     if (abortSignal && onAbort) {
  #|       try { abortSignal.removeEventListener('abort', onAbort); } catch {}
  #|     }
  #|     if (hardTimer !== null) {
  #|       clearTimeout(hardTimer);
  #|       hardTimer = null;
  #|     }
  #|   };
  #|   const killHard = () => {
  #|     if (proc.code !== null) return;
  #|     try { proc.child.kill('SIGKILL'); } catch {}
  #|   };
  #|   const cancel = () => {
  #|     if (proc.code !== null) return;
  #|     if (hard) {
  #|       killHard();
  #|       return;
  #|     }
  #|     try { proc.child.kill(signalName || 'SIGTERM'); } catch {}
  #|     const ms = Math.max(0, timeoutMs | 0);
  #|     if (ms <= 0) {
  #|       killHard();
  #|     } else {
  #|       hardTimer = setTimeout(killHard, ms);
  #|     }
  #|   };
  #|   const onAbort = () => cancel();
  #|   if (abortSignal?.aborted) {
  #|     cancel();
  #|   } else {
  #|     abortSignal?.addEventListener?.('abort', onAbort, { once: true });
  #|   }
  #|   try {
  #|     return await wait;
  #|   } finally {
  #|     cleanup();
  #|   }
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
fn signal_to_js(signal : @signal.Signal) -> String {
  match signal {
    SIGINT => "SIGINT"
    SIGTERM => "SIGTERM"
    SIGHUP => "SIGHUP"
    SIGBREAK => "SIGBREAK"
  }
}

///|
fn cancel_to_js(handler : CancellationHandler) -> (Bool, Int, String) {
  match handler.kind {
    Hard => (true, 0, "SIGKILL")
    Graceful(timeout, signal) =>
      (false, timeout, signal.map(signal_to_js).unwrap_or("SIGTERM"))
  }
}

///|
async fn wait_with_cancel(id : Int, handler : CancellationHandler) -> Int {
  let (hard, timeout_ms, signal_name) = cancel_to_js(handler)
  @js_async.run_promise(abort_signal => {
    js_process_wait_with_cancel(id, hard, timeout_ms, signal_name, abort_signal).cast()
  }) catch {
    _ if @async.is_being_cancelled() =>
      @async.protect_from_cancel(() => run_js_promise(js_process_wait(id)))
    err => raise err
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
  wait_with_cancel(proc.id, cancel_handler)
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
  @async.with_task_group(group => {
    defer stdout_r.close()
    defer stderr_r.close()
    let code_task = group.spawn(() => {
      run_internal(
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
    })
    let stdout_task = group.spawn(() => stdout_r.read_all())
    let stderr = stderr_r.read_all()
    (code_task.wait(), stdout_task.wait(), stderr)
  })
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
  @async.with_task_group(group => {
    defer stdout_r.close()
    let code_task = group.spawn(() => {
      run_internal(
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
    })
    let stdout = stdout_r.read_all()
    (code_task.wait(), stdout)
  })
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
  @async.with_task_group(group => {
    defer stderr_r.close()
    let code_task = group.spawn(() => {
      run_internal(
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
    })
    let stderr = stderr_r.read_all()
    (code_task.wait(), stderr)
  })
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
  @async.with_task_group(group => {
    defer r.close()
    let code_task = group.spawn(() => {
      run_internal(
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
    })
    let output = r.read_all()
    (code_task.wait(), output)
  })
}

///|
pub struct Process {
  pid : Int
  priv result : @async.Task[Int]
}

///|
pub async fn Process::wait(self : Process) -> Int {
  self.result.wait()
}

///|
pub fn Process::try_wait(self : Process) -> Int? raise {
  self.result.try_wait()
}

///|
pub fn Process::cancel(self : Process) -> Unit {
  self.result.cancel()
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
  let result = group.spawn(no_wait?, () => wait_with_cancel(id, cancel_handler))
  Process::{ pid: start.pid, result }
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
pub async fn wait_pid(pid : Int) -> Int {
  run_js_promise(js_process_wait_pid(pid))
}
