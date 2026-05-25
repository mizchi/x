# mizchi/fswatch

Cross-platform filesystem watcher for [MoonBit](https://docs.moonbitlang.com).

`@fswatch.start(roots)` returns a `Watcher` that emits `Event { path, kind: Created | Modified | Removed }` for changes under each root. The backend is selected at runtime:

| OS | Backend | Latency |
|---|---|---|
| macOS | FSEvents (via `dlopen`, no `-framework` link dep) | ~50 ms drain interval, OS-driven detection |
| Linux | inotify | ~50 ms drain interval, kernel-driven detection |
| Other native | Polling (mtime + size fingerprint) | ~500 ms scan interval |

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

- Linux runtime is currently un-CI'd; tested only via syntax compile on macOS. Wire up Linux CI before depending on inotify in production.
- inotify's per-user watch limit (`/proc/sys/fs/inotify/max_user_watches`) caps deeply-recursive trees.
- Windows backend (ReadDirectoryChangesW) not implemented yet — Windows native falls through to polling.
- No event-time wakeup; the drain loop polls at `interval_ms`. Sub-50ms latency would need a pipe-wake bridge from the reader thread into the MoonBit async runtime.
