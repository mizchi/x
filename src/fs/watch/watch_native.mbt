///|
/// A filesystem watcher built on a polling backend. Calls to `next` block
/// until at least one change is observed, then return the batch of events
/// seen during that scan.
pub struct Watcher {
  priv roots : Array[String]
  priv interval_ms : Int
  priv exclude : (String) -> Bool
  priv mut snapshot : Map[String, Int64]
  priv mut closed : Bool
}

///|
fn default_exclude(_ : String) -> Bool {
  false
}

///|
/// Start a polling watcher rooted at `roots`. Each entry must be a
/// directory; paths are tracked recursively. `interval_ms` controls the
/// scan cadence (default 500 ms). `exclude` is applied per path; returning
/// `true` drops both the entry and (for directories) its descendants from
/// tracking, mirroring `@xfs.walk`'s exclusion semantics.
pub async fn start(
  roots : Array[String],
  interval_ms? : Int,
  exclude? : (String) -> Bool,
) -> Watcher raise {
  let interval = interval_ms.unwrap_or(500)
  let ex = exclude.unwrap_or(default_exclude)
  let initial = snapshot(roots, ex)
  Watcher::{
    roots,
    interval_ms: interval,
    exclude: ex,
    snapshot: initial,
    closed: false,
  }
}

///|
/// Block until at least one event is observed (or the watcher is closed),
/// then return all events from that scan. Returns `[]` only on close.
pub async fn Watcher::next(self : Watcher) -> Array[Event] raise {
  for ;; {
    if self.closed {
      break []
    }
    @async.sleep(self.interval_ms)
    if self.closed {
      break []
    }
    let fresh = snapshot(self.roots, self.exclude)
    let events = diff(self.snapshot, fresh)
    self.snapshot = fresh
    if events.length() > 0 {
      break events
    }
  }
}

///|
/// Mark the watcher closed. A blocked `next` returns `[]` on its next
/// scheduled wake-up.
pub fn Watcher::close(self : Watcher) -> Unit {
  self.closed = true
}

///|
async fn snapshot(
  roots : Array[String],
  exclude : (String) -> Bool,
) -> Map[String, Int64] raise {
  let snap : Map[String, Int64] = Map([])
  for root in roots {
    if !@xfs.exists(root) {
      continue
    }
    @xfs.walk(root, max_concurrency=4, exclude=exclude, async fn(dir, names) {
      for name in names {
        let full = dir + "/" + name
        if exclude(full) {
          continue
        }
        let k = try? @xfs.kind(full)
        match k {
          Ok(Regular) => {
            let m = try? @xfs.mtime(full)
            match m {
              Ok((sec, _nsec)) => snap[full] = sec
              Err(_) => ()
            }
          }
          _ => ()
        }
      }
    })
  }
  snap
}

///|
fn diff(
  old : Map[String, Int64],
  fresh : Map[String, Int64],
) -> Array[Event] {
  let events : Array[Event] = []
  for path, mtime in fresh {
    match old.get(path) {
      None => events.push(Event::{ path, kind: Created })
      Some(prev) =>
        if prev != mtime {
          events.push(Event::{ path, kind: Modified })
        }
    }
  }
  for path, _ in old {
    if !fresh.contains(path) {
      events.push(Event::{ path, kind: Removed })
    }
  }
  events
}
