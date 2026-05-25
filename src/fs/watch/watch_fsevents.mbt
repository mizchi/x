///|
/// FSEvents backend (macOS). On non-macOS the underlying FFI returns 0 from
/// `start`, so callers fall through to the polling backend.
#borrow(paths)
extern "C" fn fsevents_start_ffi(
  paths : Bytes,
  total_len : Int,
  num_paths : Int,
  latency_ms : Double,
) -> Int64 = "mizchi_x_watch_fsevents_start"

///|
#borrow(out_buf)
extern "C" fn fsevents_pop_ffi(
  handle : Int64,
  out_buf : FixedArray[Byte],
  out_cap : Int,
) -> Int = "mizchi_x_watch_fsevents_pop"

///|
extern "C" fn fsevents_close_ffi(handle : Int64) -> Unit = "mizchi_x_watch_fsevents_close"

///|
priv struct FSEventsState {
  handle : Int64
  interval_ms : Int
  exclude : (String) -> Bool
  // (canonical_prefix, original_root): FSEvents emits canonical paths,
  // we rewrite them back so callers see the same prefixes they passed in.
  prefix_map : Array[(String, String)]
  // Paths known to be regular files at start (or seen in prior events).
  // FSEvents' Created/Modified flag bits are coalesced and unreliable for
  // disambiguating "new file" vs "existing file modified"; we use this
  // set to decide instead.
  known : Map[String, Bool]
}

///|
/// Returns `None` on non-Apple platforms or if FSEvents framework is
/// unreachable for some reason (dlopen failure, etc).
async fn fsevents_start(
  roots : Array[String],
  interval_ms : Int,
  exclude : (String) -> Bool,
  latency_ms : Double,
) -> FSEventsState? {
  // Join roots as null-byte-separated UTF-8 buffer.
  let buf = StringBuilder::new()
  for root in roots {
    buf.write_string(root)
    buf.write_char('\u{00}')
  }
  let joined = @utf8.encode(buf.to_string())
  let handle = fsevents_start_ffi(
    joined,
    joined.length(),
    roots.length(),
    latency_ms,
  )
  if handle == 0 {
    return None
  }
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
  // Seed `known` so the first event for a pre-existing file is reported as
  // Modified rather than Created.
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
  Some(FSEventsState::{ handle, interval_ms, exclude, prefix_map, known })
}

///|
fn rewrite_path(path : String, prefix_map : Array[(String, String)]) -> String {
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
/// Drain all currently-buffered FSEvents events. FSEvents flag semantics:
///   ItemCreated  = 0x00000100
///   ItemRemoved  = 0x00000200
///   ItemRenamed  = 0x00000800
///   ItemModified = 0x00001000
async fn fsevents_drain(state : FSEventsState) -> Array[Event] {
  let events : Array[Event] = []
  let cap = 4096
  let buf : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
  let ex = state.exclude
  for ;; {
    let path_len = fsevents_pop_ffi(state.handle, buf, cap)
    if path_len == -2 {
      break
    }
    if path_len < 0 {
      // -1 = path didn't fit; with cap=4096 this is unusual but skip safely
      continue
    }
    let f = (buf[0].to_int() & 0xff).reinterpret_as_uint() |
            ((buf[1].to_int() & 0xff).reinterpret_as_uint() << 8) |
            ((buf[2].to_int() & 0xff).reinterpret_as_uint() << 16) |
            ((buf[3].to_int() & 0xff).reinterpret_as_uint() << 24)
    let path_bytes = FixedArray::make(path_len, b'\x00')
    if path_len > 0 {
      FixedArray::unsafe_blit(path_bytes, 0, buf, 4, path_len)
    }
    let raw_path = @utf8.decode_lossy(Bytes::from_array(path_bytes))
    let path = rewrite_path(raw_path, state.prefix_map)
    if ex(path) {
      continue
    }
    // FSEvents flag bits accumulate across the batch (Created stays set even
    // for files that pre-existed). Use stat + our `known` set as ground truth.
    let exists_now = @xfs.exists(raw_path)
    let _ = f
    if !exists_now {
      if state.known.contains(path) {
        state.known.remove(path)
        events.push(Event::{ path, kind: Removed })
      }
      // else: never knew about it; suppress.
    } else {
      // Only track regular files; directory creations are pruned.
      let kind_ok = (try? @xfs.kind(raw_path)) is Ok(Regular)
      if !kind_ok {
        continue
      }
      let was_known = state.known.contains(path)
      state.known[path] = true
      let kind : EventKind = if was_known { Modified } else { Created }
      events.push(Event::{ path, kind })
    }
  }
  events
}

///|
async fn fsevents_next(state : FSEventsState) -> Array[Event] {
  @async.sleep(state.interval_ms)
  fsevents_drain(state)
}

///|
fn fsevents_close(state : FSEventsState) -> Unit {
  fsevents_close_ffi(state.handle)
}
