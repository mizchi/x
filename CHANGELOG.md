# Changelog

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
