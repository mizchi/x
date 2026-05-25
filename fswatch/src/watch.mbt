///|
/// Cross-target filesystem watcher event types. The concrete `Watcher`
/// struct and its `start` / `next` / `close` methods are defined per
/// target — native dispatches across FSEvents (macOS) / inotify (Linux)
/// / ReadDirectoryChangesW (Windows) / polling; js uses Node `fs.watch`.
pub(all) enum EventKind {
  Created
  Modified
  Removed
} derive(Eq)

///|
pub impl Show for EventKind with fn output(self, logger) {
  logger.write_string(
    match self {
      Created => "Created"
      Modified => "Modified"
      Removed => "Removed"
    },
  )
}

///|
pub(all) struct Event {
  path : String
  kind : EventKind
}

///|
pub impl Show for Event with fn output(self, logger) {
  logger.write_string("Event{path=")
  logger.write_string(self.path)
  logger.write_string(", kind=")
  Show::output(self.kind, logger)
  logger.write_string("}")
}
