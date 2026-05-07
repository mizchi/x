///|
#external
priv type JsPromise[T]

///|
fn[T, U] JsPromise::cast(self : JsPromise[T]) -> @js_async.Promise[U] = "%identity"

///|
extern "js" fn js_read_file(path : String) -> JsPromise[String] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.readFile(path, 'utf-8');
  #| }

///|
extern "js" fn js_write_file(
  path : String,
  content : String,
) -> JsPromise[Unit] =
  #| async (path, content) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.writeFile(path, content, 'utf-8');
  #| }

///|
extern "js" fn js_exists(path : String) -> JsPromise[Bool] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   try { await fs.access(path); return true; }
  #|   catch { return false; }
  #| }

///|
extern "js" fn js_mkdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.mkdir(path, { recursive });
  #| }

///|
extern "js" fn js_readdir(
  path : String,
  include_hidden : Bool,
  include_special : Bool,
  sort : Bool,
) -> JsPromise[Array[String]] =
  #| async (path, includeHidden, includeSpecial, sort) => {
  #|   const fs = await import('node:fs/promises');
  #|   let entries = await fs.readdir(path);
  #|   if (!includeSpecial) {
  #|     entries = entries.filter(n => n !== '.' && n !== '..');
  #|   }
  #|   if (!includeHidden) {
  #|     entries = entries.filter(n => !n.startsWith('.'));
  #|   }
  #|   if (sort) {
  #|     entries.sort();
  #|   }
  #|   return entries;
  #| }

///|
extern "js" fn js_remove(path : String) -> JsPromise[Unit] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.rm(path, { force: true });
  #| }

///|
extern "js" fn js_rmdir(path : String, recursive : Bool) -> JsPromise[Unit] =
  #| async (path, recursive) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.rm(path, { recursive, force: true });
  #| }

///|
async fn[T] run_js_promise(promise : JsPromise[T]) -> T raise IOError {
  @js_async.run_promise(fn(_signal) { promise.cast() }) catch {
    err => raise IOError::IOError(err.to_string())
  }
}

///|
pub async fn read_file(path : StringView) -> &@io.Data raise IOError {
  let s : String = run_js_promise(js_read_file(path.to_string()))
  s
}

///|
pub async fn write_file(
  path : StringView,
  content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  ignore(create)
  let text = content.text() catch {
    err => raise IOError::IOError(err.to_string())
  }
  run_js_promise(js_write_file(path.to_string(), text))
}

///|
pub async fn exists(path : StringView) -> Bool {
  run_js_promise(js_exists(path.to_string())) catch {
    _ => false
  }
}

///|
pub async fn mkdir(
  path : StringView,
  permission~ : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  run_js_promise(js_mkdir(path.to_string(), recursive.unwrap_or(false)))
}

///|
pub async fn readdir(
  path : StringView,
  include_hidden? : Bool,
  include_special? : Bool,
  sort? : Bool,
) -> Array[String] raise IOError {
  run_js_promise(
    js_readdir(
      path.to_string(),
      include_hidden.unwrap_or(false),
      include_special.unwrap_or(false),
      sort.unwrap_or(false),
    ),
  )
}

///|
pub async fn remove(path : StringView) -> Unit raise IOError {
  run_js_promise(js_remove(path.to_string()))
}

///|
pub async fn rmdir(path : StringView, recursive? : Bool) -> Unit raise IOError {
  run_js_promise(js_rmdir(path.to_string(), recursive.unwrap_or(false)))
}

///|
extern "js" fn js_kind(path : String, follow_symlink : Bool) -> JsPromise[Int] =
  #| async (path, followSymlink) => {
  #|   const fs = await import('node:fs/promises');
  #|   const stat = followSymlink ? await fs.stat(path) : await fs.lstat(path);
  #|   if (stat.isFile()) return 1;
  #|   if (stat.isDirectory()) return 2;
  #|   if (stat.isSymbolicLink()) return 3;
  #|   if (stat.isSocket()) return 4;
  #|   if (stat.isFIFO()) return 5;
  #|   if (stat.isBlockDevice()) return 6;
  #|   if (stat.isCharacterDevice()) return 7;
  #|   return 0;
  #| }

///|
extern "js" fn js_realpath(path : String) -> JsPromise[String] =
  #| async (path) => {
  #|   const fs = await import('node:fs/promises');
  #|   return await fs.realpath(path);
  #| }

///|
pub async fn kind(
  path : StringView,
  follow_symlink? : Bool,
) -> FileKind raise IOError {
  let i : Int = run_js_promise(
    js_kind(path.to_string(), follow_symlink.unwrap_or(true)),
  )
  match i {
    1 => Regular
    2 => Directory
    3 => SymLink
    4 => Socket
    5 => Pipe
    6 => BlockDevice
    7 => CharDevice
    _ => Unknown
  }
}

///|
pub async fn realpath(path : StringView) -> String raise IOError {
  run_js_promise(js_realpath(path.to_string()))
}

///|
extern "js" fn js_symlink(
  target : String,
  link_path : String,
) -> JsPromise[Unit] =
  #| async (target, linkPath) => {
  #|   const fs = await import('node:fs/promises');
  #|   await fs.symlink(target, linkPath);
  #| }

///|
pub async fn symlink(
  target~ : StringView,
  link_path : StringView,
) -> Unit raise IOError {
  run_js_promise(js_symlink(target.to_string(), link_path.to_string()))
}
