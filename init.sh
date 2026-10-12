#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

QUICK=0
for arg in "$@"; do
  case "$arg" in
    --quick|-q) QUICK=1 ;;
    --help|-h)
      echo "Usage: ./init.sh [--quick]"
      echo "  --quick, -q   Format + lint only; skip build and unit tests"
      echo "  --help, -h    Show this help"
      echo "Full verification: format + lint + build + focused unit tests"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

run_check() {
  echo "RUN  $*"
  if "$@"; then
    echo "PASS $*"
  else
    local status=$?
    echo "FAIL $* (exit $status)" >&2
    return "$status"
  fi
}

require_tool() {
  if ! command -v "$1" >/dev/null; then
    echo "Required tool missing: $1; run bash scripts/setup.sh" >&2
    return 1
  fi
}

run_check require_tool swiftformat
run_check swiftformat --lint apps --verbose
run_check require_tool swiftlint
run_check swiftlint lint --strict

if [ "$QUICK" -eq 1 ]; then
  echo "SKIP build and unit tests (--quick)"
  echo "=== Quick verification passed (format + lint only) ==="
else
  run_check xcodebuild build -project apps/novels.xcodeproj -scheme novels \
    -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" -quiet
  run_check xcodebuild test -project apps/novels.xcodeproj -scheme novels \
    -destination "platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5" \
    -only-testing:novelsTests -parallel-testing-enabled NO -quiet
  echo "=== Verification passed ==="
fi
