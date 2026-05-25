///|
/// JS-target backend: Node.js `fs.watch` per root with `recursive: true`.
/// Event flow:
///   fs.watch listener pushes absolute paths onto a queue carried by
///   the opaque JS handle. `drain` pops the queue back into MoonBit
///   as a newline-separated string; each path then runs through
///   `classify_event` so callers see the same Created / Modified /
///   Removed semantics as on native.

///|
#external
priv type JsWatcherHandle

///|
extern "js" fn js_watch_start_ffi(roots_joined_lf : String) -> JsWatcherHandle =
  #| (rootsJoinedLf) => {
  #|   const fs = require('node:fs');
  #|   const handle = { watchers: [], queue: [], closed: false };
  #|   const parts = rootsJoinedLf.split('\n').filter(Boolean);
  #|   for (const root of parts) {
  #|     try {
  #|       const w = fs.watch(root, { recursive: true, persistent: true }, (eventType, filename) => {
  #|         if (handle.closed) return;
  #|         if (!filename) return;
  #|         // Normalize backslash to slash so callers see the same separators
  #|         // they passed in (Node on Windows can emit either).
  #|         const rel = String(filename).replace(/\\/g, '/');
  #|         const full = root.replace(/[\\/]+$/, '') + '/' + rel;
  #|         handle.queue.push(full);
  #|       });
  #|       w.on('error', () => {});
  #|       handle.watchers.push(w);
  #|     } catch (_) {
  #|       /* skip unreadable roots; native backends do the same */
  #|     }
  #|   }
  #|   return handle;
  #| }

///|
extern "js" fn js_watch_drain_ffi(handle : JsWatcherHandle) -> String =
  #| (handle) => {
  #|   if (!handle || handle.closed) return '';
  #|   if (handle.queue.length === 0) return '';
  #|   const out = handle.queue.join('\n');
  #|   handle.queue.length = 0;
  #|   return out;
  #| }

///|
extern "js" fn js_watch_close_ffi(handle : JsWatcherHandle) -> Unit =
  #| (handle) => {
  #|   if (!handle || handle.closed) return;
  #|   handle.closed = true;
  #|   for (const w of handle.watchers) {
  #|     try { w.close(); } catch (_) {}
  #|   }
  #|   handle.watchers.length = 0;
  #|   handle.queue.length = 0;
  #| }

///|
priv struct JsState {
  handle : JsWatcherHandle
  interval_ms : Int
  norm : NormalizeState
}

///|
/// A filesystem watcher backed by Node's `fs.watch`. The public surface
/// mirrors the native build: `start` / `Watcher::next` / `Watcher::close`
/// / `Event` / `EventKind`.
pub struct Watcher {
  priv state : JsState
  priv mut closed : Bool
}

///|
fn default_exclude(_ : String) -> Bool {
  false
}

///|
/// Start a watcher rooted at `roots`. `interval_ms` controls how often
/// `next` re-checks the JS-side queue (default 50 ms). `exclude` is
/// applied per path; returning `true` drops it. File paths that contain a
/// literal newline are not supported on this backend (Node's `fs.watch`
/// emits them through a JS string, which we deliberately split on newline
/// for the FFI boundary).
pub async fn start(
  roots : Array[String],
  interval_ms? : Int,
  exclude? : (String) -> Bool,
) -> Watcher {
  let ex = exclude.unwrap_or(default_exclude)
  let interval = interval_ms.unwrap_or(50)
  let joined = StringBuilder::new()
  let mut first = true
  for root in roots {
    if !first {
      joined.write_char('\n')
    }
    joined.write_string(root)
    first = false
  }
  let handle = js_watch_start_ffi(joined.to_string())
  let norm = build_normalize_state(roots, ex)
  Watcher::{
    state: JsState::{ handle, interval_ms: interval, norm },
    closed: false,
  }
}

///|
/// Aliases `start` on JS. Native exposes a forced-polling variant; on JS
/// there's no native backend to bypass, so `start_polling` is the same
/// thing. Kept for cross-target call-site compatibility.
pub async fn start_polling(
  roots : Array[String],
  interval_ms? : Int,
  exclude? : (String) -> Bool,
) -> Watcher {
  start(roots, interval_ms?, exclude?)
}

///|
/// Block until at least one event is observed (or the watcher is closed),
/// then return all events from that scan. Returns `[]` only on close.
pub async fn Watcher::next(self : Watcher) -> Array[Event] {
  for ;; {
    if self.closed {
      break []
    }
    @async.sleep(self.state.interval_ms)
    if self.closed {
      break []
    }
    let raw = js_watch_drain_ffi(self.state.handle)
    if raw.length() == 0 {
      continue
    }
    let events : Array[Event] = []
    for chunk in raw.split("\n") {
      let raw_path = chunk.to_owned()
      if raw_path.length() == 0 {
        continue
      }
      match classify_event(self.state.norm, raw_path) {
        Some(e) => events.push(e)
        None => ()
      }
    }
    if events.length() > 0 {
      break events
    }
  }
}

///|
/// Mark the watcher closed; closes each underlying fs.watch handle.
/// Idempotent.
pub fn Watcher::close(self : Watcher) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  js_watch_close_ffi(self.state.handle)
}
