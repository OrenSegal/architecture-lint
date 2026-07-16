#!/bin/bash
# tests/run.sh — exercises architecture-lint.sh against the fixtures in
# tests/fixtures/, asserting exit codes. Run from anywhere; paths resolve
# relative to this script.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${TEST_DIR}/../architecture-lint.sh"
FAILURES=0

check() {
  local name="$1" expect_exit="$2"
  shift 2
  local out
  out="$("$@" 2>&1)"
  local actual=$?
  if [ "$actual" -eq "$expect_exit" ]; then
    echo "PASS  ${name}"
  else
    echo "FAIL  ${name} (expected exit ${expect_exit}, got ${actual})"
    echo "$out" | sed 's/^/      /'
    FAILURES=$((FAILURES + 1))
  fi
}

# --- Boundary check: clean fixture, no forbidden imports -------------------
BASELINE_A="$(mktemp -t arch-lint-baseline-clean).json"
ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/clean/src" ARCH_LINT_BASELINE_FILE="$BASELINE_A" \
  "$SCRIPT" --init-baseline >/dev/null
check "clean fixture passes" 0 \
  env ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/clean/src" ARCH_LINT_BASELINE_FILE="$BASELINE_A" "$SCRIPT"
rm -f "$BASELINE_A"

# --- Boundary check: Domain importing UI is a violation --------------------
BASELINE_B="$(mktemp -t arch-lint-baseline-violation).json"
ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/violation/src" ARCH_LINT_BASELINE_FILE="$BASELINE_B" \
  "$SCRIPT" --init-baseline >/dev/null
check "Domain importing UI fails" 1 \
  env ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/violation/src" ARCH_LINT_BASELINE_FILE="$BASELINE_B" "$SCRIPT"
rm -f "$BASELINE_B"

# --- Ratchet: at-baseline singleton count passes ----------------------------
BASELINE_C="$(mktemp -t arch-lint-baseline-singleton-ok).json"
ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/singleton-ok/src" ARCH_LINT_FILE_GLOB='*.swift' \
  ARCH_LINT_BASELINE_FILE="$BASELINE_C" "$SCRIPT" --init-baseline >/dev/null
check "singleton at baseline passes" 0 \
  env ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/singleton-ok/src" ARCH_LINT_FILE_GLOB='*.swift' \
  ARCH_LINT_BASELINE_FILE="$BASELINE_C" "$SCRIPT"

# --- Ratchet: new singleton beyond baseline is a regression -----------------
check "new singleton beyond baseline fails" 1 \
  env ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/singleton-regression/src" ARCH_LINT_FILE_GLOB='*.swift' \
  ARCH_LINT_BASELINE_FILE="$BASELINE_C" "$SCRIPT"
rm -f "$BASELINE_C"

# --- Inline exemption: an exempted singleton doesn't count ------------------
BASELINE_D="$(mktemp -t arch-lint-baseline-exempt).json"
ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/singleton-exempt/src" ARCH_LINT_FILE_GLOB='*.swift' \
  ARCH_LINT_BASELINE_FILE="$BASELINE_D" "$SCRIPT" --init-baseline >/dev/null
check "arch-exempt comment excludes singleton from count" 0 \
  env ARCH_LINT_MODULES_ROOT="${TEST_DIR}/fixtures/singleton-exempt/src" ARCH_LINT_FILE_GLOB='*.swift' \
  ARCH_LINT_BASELINE_FILE="$BASELINE_D" "$SCRIPT"
rm -f "$BASELINE_D"

echo ""
if [ "$FAILURES" -gt 0 ]; then
  echo "${FAILURES} test(s) failed"
  exit 1
fi
echo "All tests passed"
