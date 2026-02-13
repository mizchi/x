#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
PORT="${PORT:-18080}"
VUS="${VUS:-128}"
DURATION="${DURATION:-20s}"
BODY_SIZE="${BODY_SIZE:-16384}"
BASE_URL="http://127.0.0.1:${PORT}"

PING_SUMMARY="${PING_SUMMARY:-/tmp/k6_ping_summary.json}"
CONSUME_SUMMARY="${CONSUME_SUMMARY:-/tmp/k6_consume_summary.json}"
DISCARD_SUMMARY="${DISCARD_SUMMARY:-/tmp/k6_discard_summary.json}"
SERVER_LOG="${SERVER_LOG:-/tmp/httpbench.log}"

cleanup() {
  if [[ -n "${SERVER_PID:-}" ]]; then
    kill "${SERVER_PID}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

cd "${ROOT_DIR}"
PORT="${PORT}" moon run --target js src/httpbench --release >"${SERVER_LOG}" 2>&1 &
SERVER_PID=$!

for _ in $(seq 1 100); do
  if curl -fsS "${BASE_URL}/ping" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" \
  k6 run --summary-export "${PING_SUMMARY}" scripts/k6/http_ping.js
BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" BODY_SIZE="${BODY_SIZE}" \
  k6 run --summary-export "${CONSUME_SUMMARY}" scripts/k6/http_consume.js
BASE_URL="${BASE_URL}" VUS="${VUS}" DURATION="${DURATION}" BODY_SIZE="${BODY_SIZE}" \
  k6 run --summary-export "${DISCARD_SUMMARY}" scripts/k6/http_discard.js

jq -n \
  --slurpfile ping "${PING_SUMMARY}" \
  --slurpfile consume "${CONSUME_SUMMARY}" \
  --slurpfile discard "${DISCARD_SUMMARY}" \
  '{
    ping: {
      req_rate: $ping[0].metrics.http_reqs.rate,
      avg_ms: $ping[0].metrics.http_req_duration.avg,
      p95_ms: $ping[0].metrics.http_req_duration["p(95)"]
    },
    consume: {
      req_rate: $consume[0].metrics.http_reqs.rate,
      avg_ms: $consume[0].metrics.http_req_duration.avg,
      p95_ms: $consume[0].metrics.http_req_duration["p(95)"]
    },
    discard: {
      req_rate: $discard[0].metrics.http_reqs.rate,
      avg_ms: $discard[0].metrics.http_req_duration.avg,
      p95_ms: $discard[0].metrics.http_req_duration["p(95)"]
    }
  }'
