///|
priv struct SpawnResult {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
extern "js" fn spawn_and_collect(
  cmd : String,
  args : Array[String],
  cwd : String?,
) -> JsPromise[SpawnResult] =
  #| async (cmd, args, cwd) => {
  #|   const { spawn } = await import('node:child_process');
  #|   return new Promise((resolve, reject) => {
  #|     const options = {};
  #|     if (cwd !== undefined) options.cwd = cwd;
  #|     const child = spawn(cmd, args, options);
  #|     let stdout = '';
  #|     let stderr = '';
  #|     child.stdout.on('data', (data) => { stdout += data.toString(); });
  #|     child.stderr.on('data', (data) => { stderr += data.toString(); });
  #|     child.on('error', (err) => {
  #|       reject(err);
  #|     });
  #|     child.on('close', (code) => {
  #|       resolve({ exit_code: code ?? 0, stdout, stderr });
  #|     });
  #|   });
  #| }

///|
async fn collect_output_internal(
  cmd : StringView,
  args : ArrayView[String],
  cwd? : StringView,
) -> (Int, &@async_io.Data, &@async_io.Data) {
  let promise = spawn_and_collect(
    cmd.to_string(),
    Array::from_iter(args.iter().map(fn(s) { s })),
    cwd.map(fn(c) { c.to_string() }),
  )
  let result : SpawnResult = @js_async.run_promise(fn(_signal) {
    promise.cast()
  })
  (result.exit_code, result.stdout, result.stderr)
}
