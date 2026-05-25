///|
/// Filesystem watcher. Polling-only for now (cross-platform); native
/// fsevents/inotify/ReadDirectoryChangesW backends can replace the
/// implementation behind the same `Watcher` / `Event` surface later
/// without touching callers.
pub(all) enum EventKind {
  Created
  Modified
  Removed
} derive(Eq)

///|
pub impl Show for EventKind with output(self, logger) {
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
pub impl Show for Event with output(self, logger) {
  logger.write_string("Event{path=")
  logger.write_string(self.path)
  logger.write_string(", kind=")
  Show::output(self.kind, logger)
  logger.write_string("}")
}
