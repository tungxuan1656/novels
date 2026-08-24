#!/usr/bin/env bash
set -o pipefail

# Add only commands supported by repository evidence.
# Keep at least one BUILD_TASKS or TEST_TASKS entry when a build/test exists; otherwise keep an explicit commented SKIP with evidence.
# Set HARNESS_JOBS to limit concurrent build and test tasks.
MAX_JOBS="${HARNESS_JOBS:-4}"
STATUS=0

FORMAT_TASKS=(
  # "pnpm run format:write"
)

LINT_TASKS=(
  # "pnpm run lint -- --fix"
)

BUILD_TASKS=(
  # "pnpm run build"
)

TEST_TASKS=(
  # "pnpm run test"
)

if ! [[ "$MAX_JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "FAIL HARNESS_JOBS must be a positive integer" >&2
  exit 2
fi

# Guard: require at least one BUILD or TEST task when repo has evidence.
# If repository truly has no suite, keep explicit commented example with SKIP evidence
# (e.g. # "pnpm run test" # SKIP explicit: no test dir). Silent all-empty is a harness misconfiguration.
if [ "${#BUILD_TASKS[@]}" -eq 0 ] && [ "${#TEST_TASKS[@]}" -eq 0 ]; then
  echo "FAIL init.sh not configured: no BUILD/TEST tasks (see SKILL.md#Write init.sh from evidence)" >&2
  echo "Hint: add BUILD_TASKS/TEST_TASKS from package.json scripts, or keep explicit commented SKIP with evidence" >&2
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
