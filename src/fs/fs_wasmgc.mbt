///|
pub fn read_file(
  _path : StringView,
  sync_timestamp? : Bool,
) -> &@io.Data raise IOError {
  ignore(sync_timestamp)
  raise IOError::IOError("read_file is not supported on wasm target")
}

///|
pub fn write_file(
  _path : StringView,
  _content : &@io.Data,
  create_mode? : CreateMode,
  permission? : Int,
  sync? : SyncMode,
  append? : Bool,
  create? : Int,
  truncate? : Bool,
) -> Unit raise IOError {
  ignore(create_mode)
  ignore(permission)
  ignore(sync)
  ignore(append)
  ignore(create)
  ignore(truncate)
  raise IOError::IOError("write_file is not supported on wasm target")
}

///|
pub fn exists(_path : StringView) -> Bool {
  false
}

///|
pub fn can_read(_path : StringView) -> Bool {
  false
}

///|
pub fn can_write(_path : StringView) -> Bool {
  false
}

///|
pub fn can_execute(_path : StringView) -> Bool {
  false
}

///|
pub fn chmod(_path : StringView, _permission : Int) -> Unit raise IOError {
  raise IOError::IOError("chmod is not supported on wasm target")
}

///|
pub fn atime(
  _path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int) raise IOError {
  ignore(follow_symlink)
  raise IOError::IOError("atime is not supported on wasm target")
}

///|
pub fn mtime(
  _path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int) raise IOError {
  ignore(follow_symlink)
  raise IOError::IOError("mtime is not supported on wasm target")
}

///|
pub fn ctime(
  _path : StringView,
  follow_symlink? : Bool,
) -> (Int64, Int) raise IOError {
  ignore(follow_symlink)
  raise IOError::IOError("ctime is not supported on wasm target")
}

///|
pub fn mkdir(
  _path : StringView,
  permission? : Int,
  recursive? : Bool,
) -> Unit raise IOError {
  ignore(permission)
  ignore(recursive)
  raise IOError::IOError("mkdir is not supported on wasm target")
}

///|
pub fn readdir(
  _path : StringView,
  include_hidden? : Bool,
  include_special? : Bool,
  sort? : Bool,
) -> Array[String] raise IOError {
  ignore(include_hidden)
  ignore(include_special)
  ignore(sort)
  raise IOError::IOError("readdir is not supported on wasm target")
}

///|
pub fn remove(_path : StringView) -> Unit raise IOError {
  raise IOError::IOError("remove is not supported on wasm target")
}

///|
pub fn rename(
  _old_path : StringView,
  _new_path : StringView,
  replace? : Bool,
) -> Unit raise IOError {
  ignore(replace)
  raise IOError::IOError("rename is not supported on wasm target")
}

///|
pub fn rmdir(_path : StringView, recursive? : Bool) -> Unit raise IOError {
  ignore(recursive)
  raise IOError::IOError("rmdir is not supported on wasm target")
}

///|
pub fn kind(
  _path : StringView,
  follow_symlink? : Bool,
) -> FileKind raise IOError {
  ignore(follow_symlink)
  raise IOError::IOError("kind is not supported on wasm target")
}

///|
pub fn realpath(_path : StringView) -> String raise IOError {
  raise IOError::IOError("realpath is not supported on wasm target")
}

///|
pub fn symlink(
  target~ : StringView,
  _link_path : StringView,
) -> Unit raise IOError {
  ignore(target)
  raise IOError::IOError("symlink is not supported on wasm target")
}

///|
pub(all) struct File {}

///|
pub fn open(
  _path : StringView,
  mode~ : Mode,
  sync? : SyncMode,
  append? : Bool,
  create_mode? : CreateMode,
  permission? : Int,
  create? : Int,
  truncate? : Bool,
) -> File raise IOError {
  ignore((mode, sync, append, create_mode, permission, create, truncate))
  raise IOError::IOError("open is not supported on wasm target")
}

///|
pub fn create(
  _path : StringView,
  allow_existing? : Bool,
  permission? : Int,
  sync? : SyncMode,
) -> File raise IOError {
  ignore((allow_existing, permission, sync))
  raise IOError::IOError("create is not supported on wasm target")
}

///|
pub fn File::close(self : File) -> Unit {
  ignore(self)
}

///|
pub fn File::fd(self : File) -> Int {
  ignore(self)
  -1
}

///|
pub fn File::as_dir(self : File) -> Directory raise IOError {
  ignore(self)
  raise IOError::IOError("File::as_dir is not supported on wasm target")
}

///|
pub fn File::kind(self : File) -> FileKind {
  ignore(self)
  Unknown
}

///|
pub fn File::size(self : File) -> Int64 raise IOError {
  ignore(self)
  raise IOError::IOError("File::size is not supported on wasm target")
}

///|
pub fn File::atime(self : File) -> (Int64, Int) raise IOError {
  ignore(self)
  raise IOError::IOError("File::atime is not supported on wasm target")
}

///|
pub fn File::mtime(self : File) -> (Int64, Int) raise IOError {
  ignore(self)
  raise IOError::IOError("File::mtime is not supported on wasm target")
}

///|
pub fn File::ctime(self : File) -> (Int64, Int) raise IOError {
  ignore(self)
  raise IOError::IOError("File::ctime is not supported on wasm target")
}

///|
pub fn File::read_at(
  self : File,
  _buf : FixedArray[Byte],
  position~ : Int64,
  offset? : Int,
  len? : Int,
) -> Int raise IOError {
  ignore((self, position, offset, len))
  raise IOError::IOError("File::read_at is not supported on wasm target")
}

///|
pub fn File::read_exactly_at(
  self : File,
  _len : Int,
  position~ : Int64,
) -> Bytes raise IOError {
  ignore((self, position))
  raise IOError::IOError(
    "File::read_exactly_at is not supported on wasm target",
  )
}

///|
pub fn File::write_at(
  self : File,
  _buf : BytesView,
  position~ : Int64,
) -> Unit raise IOError {
  ignore((self, position))
  raise IOError::IOError("File::write_at is not supported on wasm target")
}

///|
pub fn File::sync(self : File, only_data? : Bool) -> Unit raise IOError {
  ignore((self, only_data))
  raise IOError::IOError("File::sync is not supported on wasm target")
}

///|
pub fn File::lock(self : File, _lock : Lock) -> Unit raise IOError {
  ignore(self)
  raise IOError::IOError("File::lock is not supported on wasm target")
}

///|
pub fn File::try_lock(self : File, _lock : Lock) -> Bool raise IOError {
  ignore(self)
  raise IOError::IOError("File::try_lock is not supported on wasm target")
}

///|
pub fn File::unlock(self : File) -> Unit {
  ignore(self)
}

///|
pub impl @io.Reader for File with _get_internal_buffer(self) {
  ignore(self)
  @io.ReaderBuffer::new()
}

///|
pub impl @io.Reader for File with _direct_read(self, _buf, offset~, max_len~) {
  ignore((self, offset, max_len))
  raise IOError::IOError("File::read is not supported on wasm target")
}

///|
pub impl @io.Writer for File with write_once(self, _buf, offset~, len~) {
  ignore((self, offset, len))
  raise IOError::IOError("File::write is not supported on wasm target")
}

///|
pub fn tmpdir(prefix~ : StringView) -> String raise IOError {
  ignore(prefix)
  raise IOError::IOError("tmpdir is not supported on wasm target")
}

///|
pub fn walk(
  _path : StringView,
  _f : async (String, Array[String]) -> Unit,
  exclude? : (String) -> Bool,
  max_concurrency? : Int,
  allow_failure? : Bool,
) -> Unit raise IOError {
  ignore((exclude, max_concurrency, allow_failure))
  raise IOError::IOError("walk is not supported on wasm target")
}

///|
pub(all) struct Directory {}

///|
pub fn opendir(_path : StringView) -> Directory raise IOError {
  raise IOError::IOError("opendir is not supported on wasm target")
}

///|
pub fn Directory::close(self : Directory) -> Unit {
  ignore(self)
}

///|
pub fn Directory::next(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> DirectoryEntry? raise IOError {
  ignore(self)
  ignore(include_hidden)
  ignore(include_special)
  raise IOError::IOError("Directory::next is not supported on wasm target")
}

///|
pub fn Directory::read_all(
  self : Directory,
  include_hidden? : Bool,
  include_special? : Bool,
) -> Array[String] raise IOError {
  ignore(self)
  ignore(include_hidden)
  ignore(include_special)
  raise IOError::IOError("Directory::read_all is not supported on wasm target")
}
