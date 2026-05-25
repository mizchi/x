///|
priv enum Backend {
  Polling(PollingState)
  FSEvents(FSEventsState)
}

///|
/// A filesystem watcher. Calls to `next` block until at least one change is
/// observed, then return the batch of events seen during that scan.
///
/// The watcher transparently picks the fastest available backend at start:
/// FSEvents on macOS (sub-second OS-driven detection), polling fallback
/// elsewhere. Use the same surface either way.
pub struct Watcher {
  priv backend : Backend
  priv mut closed : Bool
}

///|
fn default_exclude(_ : String) -> Bool {
  false
}

///|
/// Start a watcher rooted at `roots`. Each entry must be a directory; paths
/// are tracked recursively. `interval_ms` controls how often `next` re-checks
/// for events (default 500 ms for polling, 50 ms for FSEvents). `exclude` is
/// applied per path; returning `true` drops both the entry and (for
/// directories) its descendants from tracking.
pub async fn start(
  roots : Array[String],
  interval_ms? : Int,
  exclude? : (String) -> Bool,
) -> Watcher raise {
  let ex = exclude.unwrap_or(default_exclude)
  // FSEvents coalesces events for ~50ms by default; that's also a fine drain
  // cadence so we use the same value for both.
  let fast_interval = interval_ms.unwrap_or(50)
  let slow_interval = interval_ms.unwrap_or(500)
  match fsevents_start(roots, fast_interval, ex, fast_interval.to_double()) {
    Some(state) => Watcher::{ backend: FSEvents(state), closed: false }
    None => {
      let state = polling_start(roots, slow_interval, ex)
      Watcher::{ backend: Polling(state), closed: false }
    }
  }
}

///|
/// Force the polling backend, ignoring FSEvents/inotify/etc. Useful for tests
/// that need deterministic snapshot semantics, or for environments where the
/// native backend misbehaves.
pub async fn start_polling(
  roots : Array[String],
  interval_ms? : Int,
  exclude? : (String) -> Bool,
) -> Watcher raise {
  let ex = exclude.unwrap_or(default_exclude)
  let interval = interval_ms.unwrap_or(500)
  let state = polling_start(roots, interval, ex)
  Watcher::{ backend: Polling(state), closed: false }
}

///|
/// Block until at least one event is observed (or the watcher is closed),
/// then return all events from that scan. Returns `[]` only on close.
pub async fn Watcher::next(self : Watcher) -> Array[Event] raise {
  for ;; {
    if self.closed {
      break []
    }
    let events = match self.backend {
      Polling(s) => polling_next(s)
      FSEvents(s) => fsevents_next(s)
    }
    if self.closed {
      break []
    }
    if events.length() > 0 {
      break normalize(events)
    }
  }
}

///|
/// Mark the watcher closed and release backend resources. Idempotent.
pub fn Watcher::close(self : Watcher) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  match self.backend {
    Polling(_) => ()
    FSEvents(s) => fsevents_close(s)
  }
}

///|
/// Dedupe `(path, kind)` pairs while preserving first-seen order. FSEvents
/// often emits the same Modified event twice in a single batch; polling
/// won't, but it's cheap to apply uniformly.
fn normalize(events : Array[Event]) -> Array[Event] {
  let seen : Map[String, Bool] = Map([])
  let out : Array[Event] = []
  for e in events {
    let key = e.path + "\u{00}" + e.kind.to_key()
    if !seen.contains(key) {
      seen[key] = true
      out.push(e)
    }
  }
  out
}

///|
fn EventKind::to_key(self : EventKind) -> String {
  match self {
    Created => "C"
    Modified => "M"
    Removed => "R"
  }
}
