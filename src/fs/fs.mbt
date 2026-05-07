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
