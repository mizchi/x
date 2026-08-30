#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
fixture_dir="$(mktemp -d "${TMPDIR:-/tmp}/mizchi-x-without-jsimd.XXXXXX")"

cleanup() {
  rm -rf "$fixture_dir"
}
trap cleanup EXIT

node --input-type=module - "$repo_root/package.json" <<'JS'
import { readFileSync } from "node:fs";

const packageJsonPath = process.argv[2];
const packageJson = JSON.parse(readFileSync(packageJsonPath, "utf8"));
const name = "@mizchi/jsimd-moonbit-interop";

if (packageJson.optionalDependencies?.[name] !== "0.1.0") {
  throw new Error(`${name} must be an exact optionalDependency at 0.1.0`);
}
if (packageJson.dependencies?.[name] !== undefined) {
  throw new Error(`${name} must not be a required dependency`);
}
JS

cp "$repo_root/package.json" "$repo_root/pnpm-lock.yaml" "$fixture_dir/"
cp "$repo_root/moon.mod" "$fixture_dir/"
mkdir -p "$fixture_dir/src"
cp -R "$repo_root/src/json" "$fixture_dir/src/json"

pnpm --dir "$fixture_dir" install --frozen-lockfile --no-optional --ignore-scripts

if [[ -e "$fixture_dir/node_modules/@mizchi/jsimd-moonbit-interop" ]]; then
  echo "optional jsimd interop was installed unexpectedly" >&2
  exit 1
fi

(
  cd "$fixture_dir"
  moon test --target js src/json
)

if rg -n "@mizchi/jsimd-moonbit-interop" "$fixture_dir/_build"; then
  echo "unused jsimd interop leaked into the JS output" >&2
  exit 1
fi
