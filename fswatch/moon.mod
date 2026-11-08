name = "mizchi/fswatch"

version = "0.3.0"

import {
  "mizchi/x@0.7.0",
  "moonbitlang/x@0.5.7",
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
