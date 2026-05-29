# mizchi/x

Node.js backend compatibility layer for `moonbitlang/async` in [MoonBit](https://docs.moonbitlang.com).

`mizchi/x` keeps native behavior by delegating to `moonbitlang/async`, and provides JS FFI implementations so the same async-style code can run on `--target js` (Node.js) with minimal changes.

## Primary Goal

- Run code written against `moonbitlang/async` on Node.js (`--target js`).
- Keep native (`--target native`) semantics close by forwarding to upstream implementations.

## Related Package

- `mizchi/x`: API is aligned with `moonbitlang/async` contracts (native-compatible surface).
- `mizchi/js/node`: API is aligned with raw Node.js/JavaScript style APIs.

## Dependencies

| Dependency | Version |
|---|---|
| `moonbitlang/async` | 0.19.0 |
| `moonbitlang/x` | 0.4.43 |
| `moonbitlang/regexp` | 0.3.5 |
| `mizchi/simd` | 0.3.0 |

## Packages

| Package | Description |
|---|---|
| `mizchi/x/process` | Command execution (`run`, `spawn`, `spawn_orphan`, `wait_pid`, process pipes, file/stdio redirects, native pipe redirects, `collect_output`, `collect_stdout`, `collect_stderr`, `collect_output_merged`) |
| `mizchi/x/fs` | File system operations (`open`, `create`, `File`, `read_file`, `write_file`, `tmpdir`, `walk`, `exists`, `mkdir`, `readdir`, `opendir`, `Directory::next`, `rename`, `remove`, `rmdir`) |
| `mizchi/x/http` | HTTP client/server (`get`, `post`, `put`, `get_stream`, `post_stream`, `put_stream`, `Client`, `Server`, `Cookie`) |
| `mizchi/x/gzip` | Gzip stream encoder/decoder (`Encoder`, `Decoder`) |
| `mizchi/x/tls` | TLS client/server streams (`Tls::client`, `Tls::server_from_pair`, peer certificate, channel binding, `rand_bytes`, `sha1`) |
| `mizchi/x/socket` | TCP/UDP sockets (`Addr`, `Tcp`, `TcpServer`, `UdpClient`, `UdpServer`) |
| `mizchi/x/signal` | Signal constants and global cancellation signal configuration (`Signal`, `to_int`, `set_global_cancellation_signals`) |
| `mizchi/x/raw_fd` | Raw file descriptor reads/writes (`RawFd::read`, `RawFd::write`, `RawFd::close`) |
| `mizchi/x/aqueue` | Async queue (`Queue`, `Kind`, `put`, `get`, `try_put`, `try_get`, `close`) |
| `mizchi/x/cond_var` | Async condition variable (`Cond::wait`, `Cond::signal`, `Cond::broadcast`) |
| `mizchi/x/semaphore` | Async semaphore (`Semaphore::acquire`, `release`, `try_acquire`) |
| `mizchi/x/websocket` | WebSocket client/server upgrade (`connect`, `from_http_server`, `Conn::send_text`, `Conn::send_binary`, `Conn::recv`, `Conn::close`) |
| `mizchi/x/stdio` | Standard I/O (`stdin`, `stdout`, `stderr` with `@io.Reader`/`@io.Writer`) |
| `mizchi/x/pipe` | In-memory pipes (`pipe()` → `PipeRead`/`PipeWrite` with `@io.Reader`/`@io.Writer`; native process redirect support) |
| `mizchi/x/sys` | Environment variables and CLI args (`get_env_var`, `get_cli_args`, `exit`) |
| `mizchi/x/regexp` | Regular expressions mirroring `moonbitlang/regexp` (`compile`, `Regexp::execute`, `match_`, `group_by_name`, `group_count`, `group_names`, `MatchResult::matched`/`get`/`groups`/`results`/`before`/`after`) |
| `mizchi/x/json` | JSON mirroring `moonbitlang/core/json` (`parse`, `valid`, `stringify`) over the builtin `Json` value type |

## Platform Support

| Package | native | js | wasm | wasm-gc |
|---|---|---|---|---|
| `process` | Yes | Yes | stub | stub |
| `fs` | Yes | Yes | WASI P1 | stub |
| `http` | Yes | Yes | stub | stub |
| `gzip` | Yes | Yes | Yes | Yes |
| `tls` | Yes | Yes | stub | stub |
| `socket` | TCP/UDP | TCP/UDP | stub | stub |
| `signal` | Yes | constants/no-op | constants/no-op | constants/no-op |
| `raw_fd` | Yes | Yes | stub | stub |
| `aqueue` | Yes | Yes | Yes | Yes |
| `cond_var` | Yes | Yes | Yes | Yes |
| `semaphore` | Yes | Yes | Yes | Yes |
| `websocket` | Yes | Yes | stub | stub |
| `stdio` | Yes | Yes | stub | stub |
| `pipe` | Yes | Yes | stub | stub |
| `sys` | Yes | Yes | Yes | stub |
| `regexp` | Yes | Yes (FFI) | Yes | Yes |
| `json` | Yes | Yes (FFI) | simdjson | simdjson |

- **Yes** — Full implementation.
- **stub** — Compiles but aborts at runtime with "not supported" message.
- **WASI P1** — Partial implementation using WASI Preview 1 syscalls.

## Upstream Compatibility

Compatibility with `moonbitlang/async` 0.19.0 / `moonbitlang/x` 0.4.43.

The wrapper re-exports upstream types and APIs with matching signatures. On native, each function delegates directly to the upstream implementation. On JS, equivalent behavior is provided via `extern "js"` FFI (Node.js).

### Extension Notes

`mizchi/x/fs` now exposes the upstream-style `File` API (`open`, `create`, stream `@io.Reader`/`@io.Writer`, random access, size, timestamps, sync, `tmpdir`, and `walk`) on native and Node.js. Native delegates to `moonbitlang/async/fs`; JS maps to `node:fs/promises`. JS file locking is not supported because Node.js has no standard advisory file-locking API.

`mizchi/x/socket` currently covers TCP and UDP on native and Node.js. Native delegates to `moonbitlang/async/socket`; JS maps TCP to `node:net` and UDP to `node:dgram`. Node.js does not expose stable OS file descriptors for these sockets, so `fd()` returns `-1` on JS. TCP connect/accept/run_forever and UDP unicast roundtrips are covered by automated tests. UDP multicast helpers are mapped to Node where available, but multicast is not covered by automated tests.

`mizchi/x/process` exposes async 0.19 process inputs/outputs, file redirection, `spawn`, `spawn_orphan`, `wait_pid`, `Process::wait`, `Process::try_wait`, and cancellation handlers. Native delegates to `moonbitlang/async/process`; JS maps to `node:child_process`.

`mizchi/x/http` includes async 0.19 response cookies and upstream-style streaming requests: `get_stream` returns a `Client`, while `post_stream`/`put_stream` return a writable `Client` whose response is obtained with `end_request()`. Native supports upstream proxy/trust options; JS returns `NotSupported` for proxy clients and custom TLS trust.

`mizchi/x/gzip` mirrors `moonbitlang/async/gzip` and works across native, JS, wasm, and wasm-gc via the upstream stream encoder/decoder.

`mizchi/x/regexp` mirrors the public surface of `moonbitlang/regexp`. On native, wasm, and wasm-gc it delegates to the pure-MoonBit engine. On JS it drives the host `RegExp` through FFI (using the `d` flag for capture offsets and scanning the source to number named/anonymous groups), returning the same `Regexp` / `MatchResult` API. Flag letters match upstream: `i` (ignore case), `m` (multiline), `s` (dot matches newline). The JS backend reports `Err::InternalError` for any pattern the host rejects, since it cannot classify parse failures as precisely as the native parser.

`mizchi/x/json` mirrors `parse` / `valid` / `stringify` from `moonbitlang/core/json`, reusing the builtin `Json` value type. Per target:

- **native**: delegates to the pure-MoonBit `moonbitlang/core/json`.
- **JS**: uses the host `JSON.parse` / `JSON.stringify` through FFI and converts to/from `Json`. `JSON.parse` failures are mapped to `ParseError::InvalidEof` or `InvalidChar` with a best-effort position.
- **wasm / wasm-gc**: `parse` is driven by `mizchi/simd/src/simdjson` — its `find_structural_indices` (inline-WAT v128) locates structural punctuation, and a strict recursive-descent stage 2 walks the bytes using that index stream as its spine. Anything the fast path can't parse cleanly (malformed input, lone surrogates, depth overflow) falls back to `moonbitlang/core/json`, which keeps error positions/messages identical. `valid` / `stringify` delegate to `moonbitlang/core/json` (simdjson has no serializer).

`max_nesting_depth` (default 1024) and `escape_slash` / `indent` are honored on every backend, and all backends pass the ported `moonbitlang/core/json` parse suite (`json_upstream_test.mbt`).

> **Note on the simdjson path:** it is *correctness-preserving but not faster* for one-shot parsing. Measured on wasm-gc (≈2 KB document): simdjson-driven `parse` ≈98 µs vs `moonbitlang/core/json` ≈48 µs (~2× slower). The reasons are structural and match `mizchi/simd`'s own findings: its `find_structural_indices` pipeline is only ~1.27× vs scalar (`compute_quote_mask` has no wasm CLMUL and actually loses), and one-shot parsing additionally pays to marshal the input into linear memory and to run a separate scalar stage 2 on top of the scan — whereas `moonbitlang/core/json` parses the `StringView` directly in a single fused pass. simdjson-style wins need the data resident in a SIMD buffer and amortized over heavy processing, not a parse-and-marshal round trip. The wasm path is wired up because it was requested and is fully correct; switch the wasm/wasm-gc `parse` back to the `moonbitlang/core/json` delegate if you want raw speed there.

### Benchmarks (JS target)

`*_bench_wbtest.mbt` files compare each package against its upstream engine with `moon bench --target js`. On native both sit on the same engine, so the numbers there are at parity (confirming the wrapper cost is negligible); the speedups below come from delegating to the host engine on JS. Representative run (Node.js, mean ns/iter, lower is better):

| Benchmark | `mizchi/x` (JS) | upstream (pure MoonBit) | Speedup |
|---|---|---|---|
| `regexp` execute (scan + match) | ~4.9 µs | ~167 µs | **~34×** |
| `regexp` execute + capture | ~5.1 µs | ~181 µs | **~35×** |
| `regexp` compile | ~0.95 µs | ~1.2 µs | ~1.3× |
| `json` valid | ~26 µs | ~73 µs | **~2.8×** |
| `json` stringify | ~30 µs | ~66 µs | **~2.2×** |
| `json` parse | ~67 µs | ~74 µs | ~on par |

`json` parse lands roughly on par rather than faster: `JSON.parse` is fast, but the dominant cost is rebuilding the MoonBit `Json` ADT (which the pure-MoonBit parser also pays), so the host parser's edge is largely consumed by marshalling. `valid` and `stringify` win clearly because they avoid that rebuild.

`mizchi/x/tls` mirrors `moonbitlang/async/tls`. Native delegates to the upstream OpenSSL/Schannel implementation. JS maps to Node.js `node:tls` over any `@io.Reader`/`@io.Writer` pair and supports client/server handshakes, graceful shutdown, peer certificate access, `tls-unique`/`tls-server-end-point` style channel bindings, `rand_bytes`, and `sha1`. WASM targets compile as stubs.

`mizchi/x/websocket` mirrors the client API and exposes `from_http_server` for native `mizchi/x/http` server connections. JS currently supports the client API only.

`mizchi/x/signal` mirrors the async signal constants on native and provides portable numeric constants on JS/wasm targets. Global cancellation signal setup delegates to upstream on native and is a no-op on JS/wasm.

`mizchi/x/raw_fd` owns an existing OS file descriptor and provides single read/write operations. Native uses a small C FFI shim; JS maps to Node.js `fs.read`/`fs.write`/`fs.closeSync`. WASM targets compile as stubs.

`mizchi/x/aqueue`, `mizchi/x/cond_var`, and `mizchi/x/semaphore` are thin wrappers around the async synchronization primitives, keeping the same high-level API available from this compatibility module.

#### http (`moonbitlang/async/http`)

Upstream tests: 47 | Covered: 31 | Skipped: 16

| Upstream test | Status | Notes |
|---|---|---|
| `http request` | Covered | |
| `https request` | Covered | |
| `passthrough mode` | Covered | |
| `passthrough mode remaining data` | Covered | native |
| Parser/body/cookie/gzip/sender edge cases | Covered | `http_upstream_test.mbt` mirrors applicable upstream cases |
| `request streaming` | Covered | native and JS |
| Other 16 tests | Skip | Internal parser/sender/proxy tests |

#### websocket (`moonbitlang/async/websocket`)

Upstream tests: 24 | Covered: 1 | Skipped: 23

Most upstream tests are internal (frame handling, ping/pong, UTF-8 validation) and not applicable to the wrapper's high-level API. `CloseCode conversions` is covered directly; the wrapper also has independent tests covering its own API.

#### pipe (`moonbitlang/async/pipe`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream pipe tests are fully covered.

#### stdio (`moonbitlang/async/stdio`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream stdio/process redirect tests are covered on native and JS.

#### tls (`moonbitlang/async/tls`)

Upstream tests: 9 | Covered: 9 | Skipped: 0

| Upstream test | Status | Notes |
|---|---|---|
| `one way` | Covered | native and JS |
| `echo` | Covered | native and JS |
| `` `connect` accidental close `` | Covered | native and JS |
| `` `read` already closed `` | Covered | native and JS |
| `client custom root certificate` | Covered | native and JS |
| `client custom root certificate rejects different root` | Covered | native and JS |
| `get_peer_certificate` | Covered | native and JS |
| `channel binding` | Covered | native and JS |
| `peer close connection` | Covered | native and JS |

## Quick Start

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
```

### Upstream test coverage by package

Coverage is verified by `scripts/sync-upstream-tests.sh`, which extracts test names from the upstream packages and checks that each is either covered by a wrapper test or explicitly excluded in `scripts/upstream-exclude.conf`.

#### process (`moonbitlang/async/process`)

Upstream tests: 28 | Covered: 26 | Skipped: 2

| Upstream test | Status | Notes |
|---|---|---|
| `basic wait` | Covered | |
| `basic_ls` | Covered | |
| `collect_stdout` | Covered | |
| `collect_error` | Covered | |
| `collect_output` | Covered | |
| `collect_output blocked` | Covered | |
| `collect_output_merged` | Covered | |
| `wait exitcode` | Covered | |
| `set cwd` | Covered | |
| `set_env` | Covered | |
| `set_env no inherit` | Covered | |
| `wait_pid` | Covered | |
| `basic_cat` | Covered | |
| `cancel process` | Covered | |
| `cancel process hard` | Covered | |
| `cancel process timeout` | Covered | |
| `orphan process` | Covered | |
| `spawn_in_group wait` | Covered | |
| `spawn_in_group cancel` | Covered | |
| `Process::wait` | Covered | |
| `Process::try_wait` | Covered | |
| `Process:cancel` | Covered | |
| `merge stdout and stderr` | Covered | |
| `merge multiple` | Covered | |
| `redirect to file` | Covered | |
| `kill children on hard cancel` | Skip | requires custom test program + Windows |
| `do not kill orphan children on hard cancel` | Covered | |
| `windows command line arg escape` | Skip | Windows-specific |

## HTTP Server Operations (Node.js)

### Reverse proxy / TLS termination

When running `@http.Server` behind a reverse proxy (Nginx/Caddy/ALB), terminate TLS at the proxy and forward plain HTTP to the MoonBit process.

- Enable proxy-aware client address resolution with:
  - `@http.Server::new(..., trust_proxy=true)`
- Current JS behavior:
  - `client_addr()` uses `x-forwarded-for` (first hop) and `x-forwarded-port`
  - falls back to `x-forwarded-host` port when `x-forwarded-port` is absent

Security note: set `trust_proxy=true` only when requests are guaranteed to come from trusted proxy hops.

### SSE shutdown benchmark

Run this JS-only benchmark test to check concurrent SSE shutdown behavior:

```bash
moon test --target js src/http --filter 'bench(js): graceful close time under concurrent sse'
```

The test prints a measurement line like:

```text
bench(js): sse_clients=24 graceful_close_ms=1507
```

### k6 benchmark (default: JS vs Native)

Use the dedicated benchmark server package and k6 scenarios.
By default, this runs both `js` and `native` targets and prints a comparison summary.

```bash
./scripts/k6/run_http_bench.sh
```

Environment variables:

- `PORT` (default `18080`)
- `VUS` (default `128`)
- `DURATION` (default `20s`)
- `BODY_SIZE` (default `16384`) for `POST /consume`
- `TARGETS` (default `"js native"`)
  - e.g. `TARGETS=js` to run JS only
  - e.g. `TARGETS=native` to run Native only

Individual scenarios:

```bash
BASE_URL=http://127.0.0.1:18080 k6 run scripts/k6/http_ping.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_consume.js
BASE_URL=http://127.0.0.1:18080 BODY_SIZE=16384 k6 run scripts/k6/http_discard.js
```

## License

Apache-2.0
