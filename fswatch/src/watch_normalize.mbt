///|
/// Helpers shared by the native backends (FSEvents, inotify). Each backend's
/// drain function pulls raw `(path, flag_bits)` pairs from its FFI ringbuffer
/// and feeds them through these helpers to produce coalesced Created /
/// Modified / Removed events whose paths match the user-provided roots.

///|
priv struct NormalizeState {
  exclude : (String) -> Bool
  // (canonical_prefix, original_root): backends emit OS-canonical paths
  // (e.g. macOS resolves /tmp → /private/tmp); we rewrite them back so
  // callers see the same prefixes they passed in.
  prefix_map : Array[(String, String)]
  // Paths known to be regular files at start (or seen in prior events).
  // Used to disambiguate "new file" from "existing file modified" — most
  // OS-level event flags conflate the two.
  known : Map[String, Bool]
}

///|
async fn build_normalize_state(
  roots : Array[String],
  exclude : (String) -> Bool,
) -> NormalizeState raise {
  let prefix_map : Array[(String, String)] = []
  for root in roots {
    let real = try? @xfs.realpath(root)
    match real {
      Ok(r) =>
        if r != root {
          prefix_map.push((r, root))
        }
      Err(_) => ()
    }
  }
  let known : Map[String, Bool] = Map([])
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
        if k is Ok(Regular) {
          known[full] = true
        }
      }
    })
  }
  NormalizeState::{ exclude, prefix_map, known }
}

///|
fn rewrite_path(
  path : String,
  prefix_map : Array[(String, String)],
) -> String {
  for entry in prefix_map {
    let canonical = entry.0
    let original = entry.1
    if path == canonical {
      return original
    }
    if path.length() > canonical.length() &&
      path[:canonical.length()].to_owned() == canonical &&
      path[canonical.length()] == '/' {
      return original + path[canonical.length():].to_owned()
    }
  }
  path
}

///|
/// Classify a single raw event from a native backend. The caller passes the
/// raw (canonical) path; we rewrite it for the user-facing path. Returns
/// `None` to drop the event (excluded, or a phantom Remove for a path we
/// never tracked, or a non-regular-file Create).
async fn classify_event(
  state : NormalizeState,
  raw_path : String,
) -> Event? raise {
  let path = rewrite_path(raw_path, state.prefix_map)
  if (state.exclude)(path) {
    return None
  }
  let exists_now = @xfs.exists(raw_path)
  if !exists_now {
    if state.known.contains(path) {
      state.known.remove(path)
      return Some(Event::{ path, kind: Removed })
    }
    return None
  }
  let kind_ok = (try? @xfs.kind(raw_path)) is Ok(Regular)
  if !kind_ok {
    return None
  }
  let was_known = state.known.contains(path)
  state.known[path] = true
  let kind : EventKind = if was_known { Modified } else { Created }
  Some(Event::{ path, kind })
}
