name = "mizchi/x"

version = "0.3.3"

import {
  "moonbitlang/async@0.19.1",
  "moonbitlang/x@0.4.43",
  "moonbitlang/regexp@0.3.5",
  "mizchi/simd@0.3.0",
}

readme = "README.md"

repository = "https://github.com/mizchi/x"

license = "Apache-2.0"

keywords = [
  "moonbit",
  "async",
  "backend",
  "compatibility",
  "nodejs",
  "process",
  "filesystem",
  "http",
  "gzip",
  "tls",
  "socket",
  "tcp",
  "udp",
  "signal",
  "raw-fd",
  "queue",
  "semaphore",
  "websocket",
  "wasi",
]

description = "Node.js backend compatibility layer for moonbitlang/async in MoonBit, with native delegation and JS FFI implementations for process, fs, http, gzip, tls, socket, raw_fd, signal, sync primitives, websocket, stdio, pipe, and sys."

preferred_target = "native"

options(
  source: "src",
)
