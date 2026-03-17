#!/usr/bin/env bash
# Entry point: ./tests/run-tests.sh [tier1|tier2|all]
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")" && pwd)"
BATS="$TESTS_DIR/lib/bats-core/bin/bats"

usage() {
    echo "Usage: $0 [tier1|tier2|all]"
    echo ""
    echo "  tier1  Static analysis (no running stack required)"
    echo "  tier2  Live script behavior tests (requires provisioned server)"
    echo "  all    Run all tiers"
    exit 1
}

TIER="${1:-all}"

_check_test_machine() {
    if [[ ! -f "$HOME/.docker-test-machine" ]]; then
        echo ""
        echo "ERROR: This machine has not been designated as a test machine."
        echo ""
        echo "Tier 2 tests modify filesystem state. To designate"
        echo "this machine as safe for these tests, run:"
        echo "  touch ~/.docker-test-machine"
        echo ""
        exit 1
    fi
}

case "$TIER" in
tier1)
    "$BATS" "$TESTS_DIR/tier1-static.bats"
    ;;
tier2)
    _check_test_machine
    "$BATS" "$TESTS_DIR/tier2-integration.bats"
    ;;
all)
    "$BATS" "$TESTS_DIR/tier1-static.bats"
    _check_test_machine
    "$BATS" "$TESTS_DIR/tier2-integration.bats"
    ;;
*)
    usage
    ;;
esac
