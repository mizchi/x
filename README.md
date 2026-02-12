# mizchi/x

Cross-platform IO abstraction for [MoonBit](https://docs.moonbitlang.com).

Wraps `moonbitlang/async` (native) and provides JS FFI implementations so that the same API works across native, JS, and WASM-GC targets.

## Dependencies

| Dependency | Version |
|---|---|
| `moonbitlang/async` | 0.16.6 |
| `moonbitlang/x` | 0.4.40 |

## Packages

| Package | Description |
|---|---|
| `mizchi/x/process` | Command execution (`run`, `collect_output`, `collect_stdout`, `collect_stderr`, `collect_output_merged`) |
| `mizchi/x/fs` | File system operations (`read_file`, `write_file`, `exists`, `mkdir`, `readdir`, `remove`, `rmdir`) |
| `mizchi/x/http` | HTTP client (`get`, `post`, `put`, `get_stream`, `post_stream`, `put_stream`) |
| `mizchi/x/websocket` | WebSocket client (`connect`, `Conn::send_text`, `Conn::send_binary`, `Conn::recv`, `Conn::close`) |
| `mizchi/x/stdio` | Standard I/O (`stdin`, `stdout`, `stderr` with `@io.Reader`/`@io.Writer`) |
| `mizchi/x/pipe` | In-memory pipes (`pipe()` → `PipeRead`/`PipeWrite` with `@io.Reader`/`@io.Writer`) |
| `mizchi/x/sys` | Environment variables and CLI args (`get_env_var`, `get_cli_args`, `exit`) |

## Platform Support

| Package | native | js | wasm | wasm-gc |
|---|---|---|---|---|
| `process` | Yes | Yes | stub | stub |
| `fs` | Yes | Yes | WASI P1 | stub |
| `http` | Yes | Yes | stub | stub |
| `websocket` | Yes | Yes | stub | stub |
| `stdio` | Yes | Yes | stub | stub |
| `pipe` | Yes | Yes | stub | stub |
| `sys` | Yes | Yes | Yes | stub |

- **Yes** — Full implementation.
- **stub** — Compiles but aborts at runtime with "not supported" message.
- **WASI P1** — Partial implementation using WASI Preview 1 syscalls.

## Test Coverage

| Package | Tests | Targets tested |
|---|---|---|
| `process` | 15 | native, js |
| `http` | 38 | native |
| `websocket` | 24 | native |
| `fs` | 4 | native |
| `pipe` | 3 | native, js |
| `stdio` | 3 | native |
| `sys` | 0 | — |
| **Total** | **87** | |

## Upstream Compatibility

Compatibility with `moonbitlang/async` 0.16.6 / `moonbitlang/x` 0.4.40.

The wrapper re-exports upstream types and APIs with matching signatures. On native, each function delegates directly to the upstream implementation. On JS, equivalent behavior is provided via `extern "js"` FFI (Node.js).

### Upstream test coverage by package

Coverage is verified by `scripts/sync-upstream-tests.sh`, which extracts test names from the upstream packages and checks that each is either covered by a wrapper test or explicitly excluded in `scripts/upstream-exclude.conf`.

#### process (`moonbitlang/async/process`)

Upstream tests: 28 | Covered: 10 | Skipped: 18

| Upstream test | Status | Notes |
|---|---|---|
| `basic wait` | Covered | |
| `basic_ls` | Covered | |
| `collect_stdout` | Covered | |
| `collect_error` | Covered | |
| `collect_output` | Covered | |
| `collect_output_merged` | Covered | |
| `wait exitcode` | Covered | |
| `set cwd` | Covered | |
| `set_env` | Covered | |
| `set_env no inherit` | Covered | |
| `basic_cat` | Skip | stdin pipe not yet exposed |
| `wait_pid` | Skip | spawn_orphan not yet exposed |
| `cancel process` | Skip | cancellation not yet exposed |
| `cancel process hard` | Skip | cancellation not yet exposed |
| `cancel process timeout` | Skip | cancellation not yet exposed |
| `orphan process` | Skip | spawn_orphan not yet exposed |
| `collect_output blocked` | Skip | stdin param not yet exposed |
| `spawn_in_group wait` | Skip | spawn not yet exposed |
| `spawn_in_group cancel` | Skip | spawn not yet exposed |
| `Process::wait` | Skip | Process type not yet exposed |
| `Process::try_wait` | Skip | Process type not yet exposed |
| `Process:cancel` | Skip | Process type not yet exposed |
| `merge stdout and stderr` | Skip | stdout/stderr redirect not yet exposed |
| `merge multiple` | Skip | spawn + pipe redirect not yet exposed |
| `redirect to file` | Skip | file redirect not yet exposed |
| `kill children on hard cancel` | Skip | requires custom test program + Windows |
| `do not kill orphan children on hard cancel` | Skip | requires custom test program + Windows |
| `windows command line arg escape` | Skip | Windows-specific |

#### http (`moonbitlang/async/http`)

Upstream tests: 20 | Covered: 2 | Skipped: 18

| Upstream test | Status | Notes |
|---|---|---|
| `http request` | Covered | |
| `https request` | Covered | |
| Other 18 tests | Skip | Internal parser/sender/proxy tests |

#### websocket (`moonbitlang/async/websocket`)

Upstream tests: 24 | Covered: 0 | Skipped: 24

All upstream tests are internal (frame handling, ping/pong, UTF-8 validation) and not applicable to the wrapper's high-level API. The wrapper has 24 independent tests covering its own API.

#### pipe (`moonbitlang/async/pipe`)

Upstream tests: 3 | Covered: 3 | Skipped: 0

All upstream pipe tests are fully covered.

#### stdio (`moonbitlang/async/stdio`)

Upstream tests: 3 | Covered: 0 | Skipped: 3

All upstream tests require process piping/redirect features (`@process.run` with redirect options).

## Quick Start

```bash
just           # check + test
just fmt       # format code
just check     # type check
just test      # run tests
```

## License

MIT
