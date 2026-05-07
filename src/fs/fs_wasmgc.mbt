///|
pub fn read_file(_path : StringView) -> &@io.Data raise IOError {
  raise IOError::IOError("read_file is not supported on wasm target")
}

///|
pub fn write_file(
  _path : StringView,
  _content : &@io.Data,
  create? : Int,
) -> Unit raise IOError {
  ignore(create)
  raise IOError::IOError("write_file is not supported on wasm target")
}

///|
pub fn exists(_path : StringView) -> Bool {
  false
}

///|
pub fn mkdir(
  _path : StringView,
  permission~ : Int,
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
