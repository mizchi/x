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
  norm : NormalizeState
}

///|
/// Returns `None` on non-Apple platforms or if FSEvents framework is
/// unreachable for some reason (dlopen failure, etc).
async fn fsevents_start(
  roots : Array[String],
  interval_ms : Int,
  exclude : (String) -> Bool,
  latency_ms : Double,
) -> FSEventsState? raise {
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
  let norm = build_normalize_state(roots, exclude)
  Some(FSEventsState::{ handle, interval_ms, norm })
}

///|
async fn fsevents_drain(state : FSEventsState) -> Array[Event] raise {
  let events : Array[Event] = []
  let cap = 4096
  let buf : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
  for ;; {
    let path_len = fsevents_pop_ffi(state.handle, buf, cap)
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
async fn fsevents_next(state : FSEventsState) -> Array[Event] raise {
  @async.sleep(state.interval_ms)
  fsevents_drain(state)
}

///|
fn fsevents_close(state : FSEventsState) -> Unit {
  fsevents_close_ffi(state.handle)
}
