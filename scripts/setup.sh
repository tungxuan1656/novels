#!/usr/bin/env bash
set -e

# setup.sh — Install Swift lint/format tools and configure git hooks for Novels
# Idempotent: safe to run multiple times.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}==> Novels setup: SwiftLint + SwiftFormat + githooks${NC}"

# Check Homebrew
if ! command -v brew >/dev/null 2>&1; then
    echo -e "${RED}Homebrew not found. Install from https://brew.sh then re-run this script.${NC}"
    exit 1
fi
echo -e "${GREEN}  brew found: $(brew --version | head -n1)${NC}"

# Install swiftlint if missing
if ! command -v swiftlint >/dev/null 2>&1; then
    echo -e "${YELLOW}  swiftlint not found — installing via brew...${NC}"
    brew install swiftlint
else
    echo -e "${GREEN}  swiftlint found: $(swiftlint version)${NC}"
fi

# Install swiftformat if missing
if ! command -v swiftformat >/dev/null 2>&1; then
    echo -e "${YELLOW}  swiftformat not found — installing via brew...${NC}"
    brew install swiftformat
else
    echo -e "${GREEN}  swiftformat found: $(swiftformat --version)${NC}"
fi

# Configure git hooks path
echo -e "${BLUE}==> Configuring git hooks...${NC}"
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
echo -e "${GREEN}  git config core.hooksPath = $(git config --get core.hooksPath)${NC}"
ls -l .githooks/pre-commit | awk '{print "  hook:", $1, $9}'

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo -e "  ${YELLOW}swiftformat .${NC}          — format entire repo"
echo -e "  ${YELLOW}swiftformat --lint .${NC}   — check formatting (CI/pre-commit)"
echo -e "  ${YELLOW}swiftlint lint --strict${NC} — lint (strict, blocks commit)"
echo -e "  ${YELLOW}swiftlint --fix${NC}         — auto-fix fixable violations"
echo ""
echo -e "Pre-commit hook is active at ${BLUE}.githooks/pre-commit${NC} and will run on git commit."
