#!/usr/bin/env bash
set -o pipefail

# Evidence-based verification for Novels (iOS).
# Repo root: apps/novels.xcodeproj (scheme novels, iOS 26.5). SwiftLint + SwiftFormat active (.swiftlint.yml, .swiftformat, .githooks/pre-commit, scripts/setup.sh).
# Keep at least one BUILD_TASKS entry when build evidence exists; explicit SKIP comments otherwise.
MAX_JOBS="${HARNESS_JOBS:-4}"
STATUS=0
QUICK=0

for arg in "$@"; do
  case "$arg" in
    --quick|-q)
      QUICK=1
      ;;
    --help|-h)
      echo "Usage: ./init.sh [--quick]"
      echo "  --quick, -q   Quick verification: format + lint + drift only (skip build/test)"
      echo "  --help, -h    Show this help"
      echo ""
      echo "Full verification (default): format + lint + build + test + drift"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

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
  "xcodebuild test -project apps/novels.xcodeproj -scheme novels -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' -only-testing:novelsTests"
  "xcodebuild test -project apps/novels.xcodeproj -scheme novelsLogicTests -destination 'platform=macOS'"
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

echo "=== Build ==="
if [ "$QUICK" -eq 1 ]; then
  echo "SKIP [build] --quick (build skipped)"
else
  run_parallel "build" "${BUILD_TASKS[@]}"
fi

echo "=== Test ==="
if [ "$QUICK" -eq 1 ]; then
  echo "SKIP [test] --quick (test skipped)"
else
  for command in "${TEST_TASKS[@]}"; do
    run_task "test" "$command" || STATUS=1
  done
fi

echo "=== Drift ==="
if [ ! -f .agents/skills/using-skills/SKILL.md ]; then
  echo "SKIP [drift] using-skills not present"
else
  SKILL_TOTAL=$(ls -d .agents/skills/*/ 2>/dev/null | wc -l | tr -d ' ')
  CLAIMED=$(grep -oE '[0-9]+ skills' .agents/skills/using-skills/SKILL.md | head -1 | grep -oE '[0-9]+' || echo 21)
  EXPECTED=$((CLAIMED+1))
  if [ "$SKILL_TOTAL" != "$EXPECTED" ]; then
    echo "FAIL [drift] using-skills catalog claims ${CLAIMED} skills but found $((SKILL_TOTAL-1)) siblings (total $SKILL_TOTAL)" >&2
    STATUS=1
  else
    echo "PASS [drift] skill catalog claims ${CLAIMED} siblings, found $((SKILL_TOTAL-1)) siblings (total $SKILL_TOTAL)"
  fi
  if grep -q "Tham chieu nhanh.*alphabet" .agents/skills/using-skills/SKILL.md; then
    echo "FAIL [drift] duplicate section Tham chieu nhanh still present" >&2
    STATUS=1
  fi
  if grep -q "Khi.*skill.*moi" .agents/skills/using-skills/SKILL.md; then
    echo "FAIL [drift] duplicate section Khi.*skill.*moi still present" >&2
    STATUS=1
  fi
  LOGIC_SWIFTS=$(awk '/\/\* novelsLogicTests \*\/ = \{/{cap=1} cap{print} cap && /sourceTree = "<group>";/{exit}' apps/novels.xcodeproj/project.pbxproj | grep -oE '[A-Za-z0-9_]+\.swift')
  if [ -z "$LOGIC_SWIFTS" ]; then
    echo "FAIL [drift] novelsLogicTests group not found in project.pbxproj" >&2
    STATUS=1
  else
    for f in $LOGIC_SWIFTS; do
      case "$f" in
        *Tests.swift)
          if [ ! -f "apps/novelsTests/$f" ]; then
            echo "FAIL [drift] $f listed in novelsLogicTests target but missing in apps/novelsTests" >&2
            STATUS=1
          elif grep -q "@testable import novels" "apps/novelsTests/$f" && ! grep -q "canImport(novels)" "apps/novelsTests/$f"; then
            echo "FAIL [drift] $f must not use unguarded @testable import (dual-membership files use #if canImport)" >&2
            STATUS=1
          fi
          ;;
        *)
          src=$(find apps/novels -name "$f" -not -path "*/novelsTests/*" | head -1)
          # Shared test helpers with dual membership (e.g. Fixtures/TolerantFixtures.swift) live under apps/novelsTests.
          if [ -z "$src" ]; then
            src=$(find apps/novelsTests -name "$f" | head -1)
          fi
          if [ -z "$src" ]; then
            echo "FAIL [drift] $f listed in novelsLogicTests target but source not found in apps/novels" >&2
            STATUS=1
          elif grep -Eq "import (UIKit|AppKit|Combine)" "$src"; then
            echo "FAIL [drift] $src must stay free of UIKit/AppKit/Combine (macOS hostless target)" >&2
            STATUS=1
          fi
          ;;
      esac
    done
  fi
  if find apps -iname "*uitest*" | grep -q .; then
    echo "FAIL [drift] UI test files/targets are not allowed (unit tests only, see AGENTS.md)" >&2
    STATUS=1
  fi
  if grep -rEq "XCUIApplication|XCUITest" apps --include="*.swift"; then
    echo "FAIL [drift] XCUITest references are not allowed (unit tests only, see AGENTS.md)" >&2
    STATUS=1
  fi
fi

if [ "$STATUS" -ne 0 ]; then
  echo "=== Verification failed ===" >&2
  exit "$STATUS"
fi

echo "=== Verification passed ==="
