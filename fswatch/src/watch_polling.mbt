///|
priv struct PollingState {
  roots : Array[String]
  interval_ms : Int
  exclude : (String) -> Bool
  mut snapshot : Map[String, Int64]
}

///|
async fn polling_start(
  roots : Array[String],
  interval_ms : Int,
  exclude : (String) -> Bool,
) -> PollingState {
  let initial = polling_snapshot(roots, exclude)
  PollingState::{ roots, interval_ms, exclude, snapshot: initial }
}

///|
async fn polling_next(state : PollingState) -> Array[Event] {
  @async.sleep(state.interval_ms)
  let fresh = polling_snapshot(state.roots, state.exclude)
  let events = polling_diff(state.snapshot, fresh)
  state.snapshot = fresh
  events
}

///|
async fn polling_snapshot(
  roots : Array[String],
  exclude : (String) -> Bool,
) -> Map[String, Int64] {
  let snap : Map[String, Int64] = Map([])
  for root in roots {
    if !@xfs.exists(root) {
      continue
    }
    @xfs.walk(root, max_concurrency=4, exclude~, async fn(dir, names) {
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
fn polling_diff(
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
