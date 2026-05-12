///|
/// File system error.
pub suberror IOError {
  IOError(String)
}

///|
pub impl Show for IOError with output(self, logger) {
  let IOError(msg) = self
  logger.write_string("IOError(\{msg})")
}

///|
/// File kind, mirroring `moonbitlang/async/fs.FileKind` (same variants and
/// numeric tags) so the same code compiles for native (delegates to
/// upstream) and JS (translated from Node `fs.lstat` / `fs.stat`).
pub(all) enum FileKind {
  Unknown = 0
  Regular = 1
  Directory = 2
  SymLink = 3
  Socket = 4
  Pipe = 5
  BlockDevice = 6
  CharDevice = 7
} derive(Eq)

///|
pub impl Show for FileKind with output(self, logger) {
  logger.write_string(
    match self {
      Unknown => "Unknown"
      Regular => "Regular"
      Directory => "Directory"
      SymLink => "SymLink"
      Socket => "Socket"
      Pipe => "Pipe"
      BlockDevice => "BlockDevice"
      CharDevice => "CharDevice"
    },
  )
}

///|
/// Directory entry returned by `Directory::next`.
pub(all) struct DirectoryEntry {
  name : String
  is_dir : Bool
}

///|
pub(all) enum Mode {
  ReadOnly
  WriteOnly
  ReadWrite
}

///|
pub(all) enum SyncMode {
  NoSync
  Data
  Full
}

///|
pub(all) enum CreateMode {
  OpenExisting
  TruncateExisting
  OpenOrCreate
  CreateOrTruncate
  CreateNew
}

///|
pub(all) enum Lock {
  Shared
  Exclusive
}
