///|
/// inotify backend (Linux). On non-Linux the underlying FFI returns 0 from
/// `start`, so callers fall through to the next backend.
#borrow(paths)
extern "C" fn inotify_start_ffi(
  paths : Bytes,
  total_len : Int,
  num_paths : Int,
) -> Int64 = "mizchi_x_watch_inotify_start"

///|
#borrow(out_buf)
extern "C" fn inotify_pop_ffi(
  handle : Int64,
  out_buf : FixedArray[Byte],
  out_cap : Int,
) -> Int = "mizchi_x_watch_inotify_pop"

///|
extern "C" fn inotify_close_ffi(handle : Int64) -> Unit = "mizchi_x_watch_inotify_close"

///|
priv struct InotifyState {
  handle : Int64
  interval_ms : Int
  norm : NormalizeState
}

///|
/// Returns `None` on non-Linux platforms or if inotify_init1 fails (e.g.
/// per-user watch limit exceeded — see /proc/sys/fs/inotify/max_user_watches).
async fn inotify_start(
  roots : Array[String],
  interval_ms : Int,
  exclude : (String) -> Bool,
) -> InotifyState? {
  let buf = StringBuilder::new()
  for root in roots {
    buf.write_string(root)
    buf.write_char('\u{00}')
  }
  let joined = @utf8.encode(buf.to_string())
  let handle = inotify_start_ffi(joined, joined.length(), roots.length())
  if handle == 0 {
    return None
  }
  let norm = build_normalize_state(roots, exclude)
  Some(InotifyState::{ handle, interval_ms, norm })
}

///|
async fn inotify_drain(state : InotifyState) -> Array[Event] {
  let events : Array[Event] = []
  let cap = 4096
  let buf : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
  for ;; {
    let path_len = inotify_pop_ffi(state.handle, buf, cap)
    if path_len == -2 {
      break
    }
    if path_len < 0 {
      continue
    }
    let path_bytes = FixedArray::make(path_len, b'\x00')
    if path_len > 0 {
      FixedArray::unsafe_blit(path_bytes, 0, buf, 4, path_len)
    }
    let raw_path = @utf8.decode_lossy(Bytes::from_array(path_bytes))
    match classify_event(state.norm, raw_path) {
      Some(e) => events.push(e)
      None => ()
    }
  }
  events
}

///|
async fn inotify_next(state : InotifyState) -> Array[Event] {
  @async.sleep(state.interval_ms)
  inotify_drain(state)
}

///|
fn inotify_close(state : InotifyState) -> Unit {
  inotify_close_ffi(state.handle)
}
