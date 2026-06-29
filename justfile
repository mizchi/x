# MoonBit Project Commands

# Default target (native for IO operations)
target := "native"

# Default task: check and test
default: check test

# Format code
fmt:
    moon fmt

# Type check
check:
    moon check --target {{target}}

# Run tests
test:
    moon test --target {{target}}

# Update snapshot tests
test-update:
    moon test --update --target {{target}}

# Generate type definition files
info:
    moon info

# Clean build artifacts
clean:
    moon clean

# Pre-release check
release-check: fmt info check test

# Pre-release check on all supported targets
release-check-all:
    just release-check
    just target=js check

# Check upstream test coverage gap
sync-tests package="":
    @if [ -n "{{package}}" ]; then \
        ./scripts/sync-upstream-tests.sh {{package}}; \
    else \
        ./scripts/sync-upstream-tests.sh; \
    fi

# Run HTTP comparison benchmark via k6 (default: js vs native)
bench-http port="18080" vus="128" duration="20s" body_size="16384":
    PORT={{port}} VUS={{vus}} DURATION={{duration}} BODY_SIZE={{body_size}} ./scripts/k6/run_http_bench.sh

# Profile a JS test with Node CPU profiler and convert it to pprof.
pprof-js-test package="http" suite="blackbox" file="http_js_only_test.mbt" start="6" end="7" out="profiles/js-http":
    mkdir -p {{out}}
    moon test --target js --build-only --package mizchi/x/{{package}}
    node --cpu-prof --cpu-prof-dir={{out}} --cpu-prof-name={{package}}-{{suite}}.cpuprofile _build/js/debug/test/{{package}}/{{package}}.{{suite}}_test.js '{"file_and_index":[["{{file}}",[{"start":{{start}},"end":{{end}}}]]]}'
    moon-pprof cpuprofile2pprof {{out}}/{{package}}-{{suite}}.cpuprofile {{out}}/{{package}}-{{suite}}.pb.gz
    moon-pprof summary {{out}}/{{package}}-{{suite}}.pb.gz

# Profile an existing wasm/wasm-gc artifact with moon-pprof.
pprof-wasm wasm out="profiles/wasm" iterations="1":
    mkdir -p {{out}}
    moon-pprof profile {{wasm}} --iterations {{iterations}} --out {{out}}/profile.pb.gz --json-out {{out}}/profile.firefox.json
    moon-pprof summary {{out}}/profile.pb.gz

# Build a wasm/wasm-gc test artifact and profile it with moon-pprof.
pprof-wasm-test package="json" backend="wasm-gc" suite="blackbox" iterations="1" out="profiles/wasm-test":
    mkdir -p {{out}}
    moon test --target {{backend}} --build-only --package mizchi/x/{{package}}
    just pprof-wasm _build/{{backend}}/debug/test/{{package}}/{{package}}.{{suite}}_test.wasm {{out}} {{iterations}}
