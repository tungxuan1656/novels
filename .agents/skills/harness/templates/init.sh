#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

run_check() {
  echo "RUN  $*"
  if "$@"; then
    echo "PASS $*"
  else
    local status=$?
    echo "FAIL $*" >&2
    return "$status"
  fi
}

run_check bash -n init.sh
run_check git diff --check
run_check git diff --cached --check
# Add the observed read-only root check here; it owns coverage and concurrency.
echo "SKIP project checks: template not configured" >&2
echo "PASS configured checks (not full repository verification)"
