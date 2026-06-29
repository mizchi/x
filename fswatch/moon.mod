name = "mizchi/fswatch"

version = "0.2.0"

import {
  "mizchi/x@0.4.0",
  "moonbitlang/async@0.20.0",
  "moonbitlang/x@0.4.46",
}

readme = "README.md"

repository = "https://github.com/mizchi/x"

license = "Apache-2.0"

keywords = [
  "moonbit",
  "filesystem",
  "watch",
  "fswatch",
  "fsevents",
  "inotify",
]

description = "Cross-platform filesystem watcher for MoonBit: FSEvents on macOS, inotify on Linux, polling fallback elsewhere."

preferred_target = "native"

source = "src"
