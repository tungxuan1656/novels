#!/usr/bin/env bash
set -o pipefail

# Evidence-based verification for Novels (iOS).
# Repo root: apps/novels.xcodeproj (scheme novels, iOS 26.5). SwiftLint + SwiftFormat active (.swiftlint.yml, .swiftformat, .githooks/pre-commit, scripts/setup.sh).
# Keep at least one BUILD_TASKS entry when build evidence exists; explicit SKIP comments otherwise.
MAX_JOBS="${HARNESS_JOBS:-4}"
STATUS=0

FORMAT_TASKS=(
  "if command -v swiftformat >/dev/null; then swiftformat --lint apps --verbose; else echo 'SKIP [format] swiftformat not installed — run bash scripts/setup.sh'; fi"
)

LINT_TASKS=(
  "if command -v swiftlint >/dev/null; then swiftlint lint --strict; else echo 'SKIP [lint] swiftlint not installed — run bash scripts/setup.sh'; fi"
)

BUILD_TASKS=(
  "xcodebuild build -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -quiet"
)

TEST_TASKS=(
  "xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'"
)

if ! [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "FAIL HARNESS_JOBS must be a positive integer" >&2
  exit 2
fi

if [ "${#BUILD_TASKS[@]}" -eq 0 ] && [ "${#TEST_TASKS[@]}" -eq 0 ]; then
  echo "FAIL init.sh not configured: no BUILD/TEST tasks (see SKILL.md#Write init.sh from evidence)" >&2
  echo "Hint: add BUILD_TASKS/TEST_TASKS from project evidence, or keep explicit commented SKIP with evidence" >&2
  exit 2
fi

run_task() {
  local phase="$1"
  local command="$2"

  echo "RUN  [$phase] $command"
  if bash -c "$command"; then
    echo "PASS [$phase] $command"
    return 0
  fi

  echo "FAIL [$phase] $command" >&2
  return 1
}

run_parallel() {
  local phase="$1"
  shift

  if [ "$#" -eq 0 ]; then
    echo "SKIP [$phase] no task configured"
    return 0
  fi

  local command
  local pid
  local -a pids=()

  for command in "$@"; do
    run_task "$phase" "$command" &
    pids+=("$!")

    if [ "${#pids[@]}" -ge "$MAX_JOBS" ]; then
      for pid in "${pids[@]}"; do
        wait "$pid" || STATUS=1
      done
      pids=()
    fi
  done

  for pid in "${pids[@]}"; do
    wait "$pid" || STATUS=1
  done
}

echo "=== Format ==="
run_parallel "format" "${FORMAT_TASKS[@]}"

echo "=== Lint ==="
run_parallel "lint" "${LINT_TASKS[@]}"

echo "=== Build and test ==="
run_parallel "build/test" "${BUILD_TASKS[@]}" "${TEST_TASKS[@]}"

if [ "$STATUS" -ne 0 ]; then
  echo "=== Verification failed ===" >&2
  exit "$STATUS"
fi

echo "=== Verification passed ==="
