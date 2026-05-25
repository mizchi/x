# mizchi/fswatch

Cross-platform filesystem watcher for [MoonBit](https://docs.moonbitlang.com).

`@fswatch.start(roots)` returns a `Watcher` that emits `Event { path, kind: Created | Modified | Removed }` for changes under each root. The backend is selected at runtime:

| Target / OS | Backend | Latency |
|---|---|---|
| native / macOS | FSEvents (via `dlopen`, no `-framework` link dep) | ~50 ms drain interval, OS-driven detection |
| native / Linux | inotify | ~50 ms drain interval, kernel-driven detection |
| native / Windows | ReadDirectoryChangesW (per-root HANDLE + OVERLAPPED, single reader thread via `WaitForMultipleObjects`) | ~50 ms drain interval, kernel-driven detection |
| native / other | Polling (mtime + size fingerprint) | ~500 ms scan interval |
| js / Node | `fs.watch` per root with `recursive: true` | ~50 ms drain interval, Node event-loop-driven detection |

All backends share a single normalization layer (`watch_normalize.mbt`): OS-canonical paths (e.g. `/private/tmp/...` on macOS) are rewritten back to the user-supplied root form, and `Created` vs `Modified` is resolved against an initial directory walk so flag-bit quirks don't cross the API surface.

## Usage

```moonbit
async fn watch_src() -> Unit raise {
  let watcher = @fswatch.start(["src", "Taskfile.pkl"])
  defer watcher.close()
  for ;; {
    let events = watcher.next()
    if events.length() == 0 { break }
    for e in events {
      println("\{e.kind} \{e.path}")
    }
  }
}
```

## Options

- `interval_ms?`: drain cadence in ms. Default 50 (native) / 500 (polling).
- `exclude?`: `(String) -> Bool`. Returning `true` drops the entry — for directories, descendants are pruned too.
- `start_polling(...)`: force the polling backend (deterministic, lets tests bypass platform quirks).

## Limitations

- Linux + Windows native runtime is validated only via CI (developing on darwin). The first CI run after the relevant commits is the first time inotify / RDCW execute end-to-end.
- inotify's per-user watch limit (`/proc/sys/fs/inotify/max_user_watches`) caps deeply-recursive trees.
- RDCW caps at 63 simultaneous roots per watcher (`MAXIMUM_WAIT_OBJECTS - 1` for the stop event). Most projects use 1–3 roots so this is moot in practice.
- Node `fs.watch` with `recursive: true` requires Node 20+ on Linux. On older versions only the top-level directory is observed.
- File paths containing literal newlines are not supported on the js backend (the FFI boundary uses `'\n'` as a separator).
- No event-time wakeup; the drain loop polls at `interval_ms`. Sub-50ms latency would need a pipe-wake bridge from the reader thread (or `fs.watch` listener) into the MoonBit async runtime.
