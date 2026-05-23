# Changelog

## 0.3.3 - 2026-05-24

### Added

- `process.kill(pid, signal)` — native `kill(2)` wrapper. Pass a negative `pid` to target a process group, mirroring POSIX semantics. Avoids spawning `/bin/kill` subprocesses for signal delivery.
- `Process::kill_tree(self, signal)` — sends `signal` to the process group whose leader is this process. Effective only when the spawn was set up as a pgid leader (see `new_process_group` below).
- `spawn(..., new_process_group~ : Bool = false)` — best-effort `setpgid(child, child)` after the child returns from posix_spawn. Documented as best-effort because the underlying `moonbitlang/async/process` doesn't expose `POSIX_SPAWN_SETPGROUP`, so there is a sub-millisecond race window where the child may exec before the parent calls setpgid. Callers that need guaranteed pgid-leader semantics should wrap the cmd in a shell that sets its own pgid (or wait for upstream to land the kernel-level flag).

Native FFI for both lives in `src/process/process_native.c`. wasm / wasm-gc / js stubs unchanged — process control on those targets is platform-specific.

## 0.3.2 - 2026-05-24

### Changed

- Skipped intermediate `Json` AST allocation in `headers_to_json` and `cookies_to_json`. Writes JSON straight into a `StringBuilder` instead of building a `Json::object` / `Json::array` and running `Json::stringify`. Measured under `moon bench --target=js --release`: `headers_to_json` -64% (3.36 µs → 1.21 µs, 8 headers), `cookies_to_json` -52% (1.94 µs → 0.92 µs, 4 cookies). Parse-side benches also improve ~30-40% due to lower GC pressure on the same process.
- Bumped `moonbitlang/async` to 0.19.1.
- Migrated module manifest from `moon.mod.json` to the new `moon.mod` format and ran `moon fmt` across the source tree (new `with fn output(...)` syntax for trait method impls, redundant `@<basename>` import aliases dropped).

### Added

- Microbenchmarks for the sync surface of `aqueue` / `cond_var` / `semaphore` / `websocket` so regressions in those wrappers can be caught by `moon bench`.

## 0.3.1 - 2026-05-13

### Added

- Added native WebSocket server upgrade support via `websocket.from_http_server`.

### Fixed

- Stabilized macOS native process tests by removing timing and output-order assumptions.
- Regenerated WebSocket package interfaces for the native HTTP server upgrade API.

## 0.3.0 - 2026-05-13

### Added

- Added compatibility wrappers for `moonbitlang/async` 0.19 APIs across process, fs, http, gzip, tls, socket, raw_fd, signal, sync primitives, websocket, stdio, pipe, and sys.
- Added Node.js support for TCP/UDP sockets, process management, filesystem APIs, HTTP client/server streaming, gzip, TLS, raw file descriptors, stdio, pipe, and WebSocket client behavior.
- Added TLS client/server support on JS via Node.js `node:tls`, including custom roots, peer certificates, channel binding helpers, `rand_bytes`, and `sha1`.
- Added upstream-style HTTP streaming request coverage for `get_stream`, `post_stream`, and `put_stream`.
- Added stdio/process redirect compatibility tests and native pipe redirect support for process stdin/stdout.

### Changed

- Aligned APIs and generated interfaces with `moonbitlang/async` 0.19.0 and `moonbitlang/x` 0.4.43.
- Improved JS process cancellation, `wait_pid`, `Process::wait`, `Process::try_wait`, and large-output collection behavior.
- Expanded upstream compatibility coverage to cover all applicable upstream tests; remaining exclusions are internal or target-specific cases.
- Updated package version to `0.3.0`.

### Fixed

- Fixed JS process output collection so stdout/stderr are read concurrently and large stderr output does not deadlock collection.
- Fixed JS process temporary output handling when stdout and stderr share the same process output.
- Fixed HTTP, process, stdio, and TLS regressions found while mirroring upstream test cases.
