# Changelog

## Unreleased

- Target MoonBit v0.10.21. Core's `async/pipe` is now internal, so the native `mizchi/x/pipe` creates an OS pipe itself (`pipe(2)`) and drives both ends through `@async_fs`; `pipe()` is `async` on native.
- Implement the new required `name` / `flush_partial_data` members of core's `BinaryReaderImpl` / `BinaryWriterImpl` for every stream type; reader/writer methods now raise `@io.ReaderError` / `@io.WriterError`.
- Socket: follow core's `Addr { ip : IpAddr, port : UInt16 }`, `recv_into` / `recv_into_with_addr` / `send`, and `IpAddr` multicast interfaces. `fd()` keeps returning `Int32` (core's `@types.Fd` is now opaque).
- FS: `File::read_at` / `read_exactly_at` / `write_at` use core's `File::at(position)` views; `read_file`'s `sync_timestamp` is accepted and ignored.
- **Breaking (native/wasm):** core's `async/tls` is client-only now, so `Tls::server` / `server_from_pair` raise `TlsError` on native and wasm (JS keeps server support; terminate TLS in a proxy otherwise). `rand_bytes` uses the OS entropy source on native and raises on wasm.
- **Breaking (wasm):** `mizchi/x/pipe` is a stub on wasm; core's OS pipe is internal now. Use `process.read_from_process` / `write_to_process` for process channels.
- Partial flushes (`flush_partial_data`) of HTTP clients/server connections and TLS streams are forwarded to the underlying writer.
- HTTP: `flush` maps to core's `flush_partial_data`; one-shot POST/PUT bodies come from core's `MessageBody`.

## 0.7.0 - 2026-11-09

- Target MoonBit v0.10.20 and import async APIs from `moonbitlang/core/async`; remove the standalone async dependency.
- Update `moonbitlang/x` to 0.5.7 and `moonbitlang/regexp` to 0.3.7; migrate the workspace to `moon.work`.
- Implement core binary stream traits while preserving text/binary convenience APIs through `mizchi/x/data`.
- Adapt HTTP connections, process results, timestamps, JS FFI arrays, and cancellation cleanup to the bundled core runtime.
- Migrate integer and derive syntax, regenerate interfaces, and add regressions for shared stream buffering and process cleanup.
- Reconcile directory notifications in the JS filesystem watcher and isolate watcher tests with temporary directories.
- Release `mizchi/fswatch` 0.3.0 with a dependency on `mizchi/x` 0.7.0.
- Explicitly reject WASM process redirection from `mizchi/x/pipe` handles, which core's new redirect enums cannot represent. Use `process.read_from_process` / `write_to_process` for process channels on WASM.

## 0.6.0 - 2026-08-30

### Added

- Added `mizchi/x/bytes`, a cross-platform `Bytes` facade for find/reverse-find, equality, shortlex comparison, and non-ASCII detection. The JS target imports `@mizchi/jsimd-moonbit-interop` with MoonBit `#module`; that package preserves MoonBit semantics while using jsimd's prebuilt Wasm SIMD kernels for large inputs.
- Added measured JS fast-path facades for `BytesView`, `StringView`, and byte-specialized `ArrayView`. BytesView reuses jsimd Wasm SIMD without copying surrounding bytes; StringView and ArrayView use bounded native JS operations. APIs that did not beat the builtin implementation are omitted.

### Changed

- Made `@mizchi/jsimd-moonbit-interop` optional. JS consumers that do not import the Bytes/BytesView/StringView/ArrayView fast-path packages no longer need to install it; CI verifies an installation with optional dependencies omitted.
- Updated deprecated `StringBuilder`, JS FFI array, and async cleanup forms for the current MoonBit toolchain so `--deny-warn` checks remain green.

## 0.5.1 - 2026-06-30

### Changed

- Bumped package patch versions for the release.

## 0.5.0 - 2026-06-30

### Changed

- Bumped `moonbitlang/async` 0.19.1 -> 0.20.0 and `moonbitlang/x` 0.4.44 -> 0.4.46.
- Bumped the `fswatch` sub-module to 0.2.0.
- Integrated the filesystem watcher API into `mizchi/x/fs` as `Watcher`, `Watcher::wait_any`, and `Watcher::close`, matching `moonbitlang/async/fs`.
- Reduced JS HTTP reader allocation churn by reusing `@io.ReaderBuffer` on `ServerConnection` and `Client`.

### Fixed

- Fixed warnings surfaced by `moon check --deny-warn`.
- Tuned HTTP/process/stdio/fswatch tests to reduce profiling noise and long waits.

## 0.4.0 - 2026-05-30

### Added

- `src/regexp/` — regular expressions (`compile`, `Regexp::execute` / `match_`, `MatchResult`) mirroring `moonbitlang/regexp`. JS target uses the native `RegExp` via `extern "js"` FFI; other targets delegate to `moonbitlang/regexp`.
- `src/json/` — JSON (`parse`, `valid`, `stringify`) over the builtin `Json` type, mirroring `moonbitlang/core/json`. JS target uses the native `JSON` via FFI.
- `src/crypto/` — hashes / HMAC / hex (`md5`, `sha1`, `sha224`, `sha256`, `sm3`, `hmac`, `bytes_to_hex_string`) mirroring `moonbitlang/x/crypto`. Pure-MoonBit delegation on all targets (synchronous, so no `crypto.subtle`).
- `fswatch` sub-module — cross-platform filesystem watcher with native + JS backends.

### Changed

- Bumped `moonbitlang/x` 0.4.43 → 0.4.44.
- Added `moonbitlang/regexp@0.3.5` to module imports.

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
