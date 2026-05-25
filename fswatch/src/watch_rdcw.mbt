///|
/// ReadDirectoryChangesW backend (Windows). On non-Windows the underlying
/// FFI returns 0 from `start`, so callers fall through to the polling backend.
#borrow(paths)
extern "C" fn rdcw_start_ffi(
  paths : Bytes,
  total_len : Int,
  num_paths : Int,
) -> Int64 = "mizchi_x_watch_rdcw_start"

///|
#borrow(out_buf)
extern "C" fn rdcw_pop_ffi(
  handle : Int64,
  out_buf : FixedArray[Byte],
  out_cap : Int,
) -> Int = "mizchi_x_watch_rdcw_pop"

///|
extern "C" fn rdcw_close_ffi(handle : Int64) -> Unit = "mizchi_x_watch_rdcw_close"

///|
priv struct RDCWState {
  handle : Int64
  interval_ms : Int
  norm : NormalizeState
}

///|
/// Returns `None` on non-Windows platforms or if any of the roots can't be
/// opened with `FILE_LIST_DIRECTORY`.
async fn rdcw_start(
  roots : Array[String],
  interval_ms : Int,
  exclude : (String) -> Bool,
) -> RDCWState? {
  let buf = StringBuilder::new()
  for root in roots {
    buf.write_string(root)
    buf.write_char('\u{00}')
  }
  let joined = @utf8.encode(buf.to_string())
  let handle = rdcw_start_ffi(joined, joined.length(), roots.length())
  if handle == 0 {
    return None
  }
  let norm = build_normalize_state(roots, exclude)
  Some(RDCWState::{ handle, interval_ms, norm })
}

///|
async fn rdcw_drain(state : RDCWState) -> Array[Event] {
  let events : Array[Event] = []
  let cap = 4096
  let buf : FixedArray[Byte] = FixedArray::make(cap, b'\x00')
  for ;; {
    let path_len = rdcw_pop_ffi(state.handle, buf, cap)
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
async fn rdcw_next(state : RDCWState) -> Array[Event] {
  @async.sleep(state.interval_ms)
  rdcw_drain(state)
}

///|
fn rdcw_close(state : RDCWState) -> Unit {
  rdcw_close_ffi(state.handle)
}
