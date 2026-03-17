#!/usr/bin/env bats
# Tier 2: Live script behavior tests.
# Requires the uptime_kuma_hooks role to have been applied to this machine.
# Requires ~/.docker-test-machine to opt in.

setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'helpers/common.bash'
    # Use a mock push URL server or a dead-letter URL for testing.
    # Scripts must succeed as long as curl is called correctly.
    # We mock curl via PATH to capture calls without real HTTP.
    MOCK_DIR="$(mktemp -d)"
    cat > "$MOCK_DIR/curl" <<'EOF'
#!/usr/bin/env bash
echo "MOCK_CURL_ARGS: $*"
exit 0
EOF
    chmod +x "$MOCK_DIR/curl"
    export PATH="$MOCK_DIR:$PATH"
    export MOCK_DIR
}

teardown() {
    rm -rf "$MOCK_DIR"
    # Restore reboot-required state if test left it behind
    rm -f /tmp/bats-reboot-required-test 2>/dev/null || true
}

# -- reboot-required check -----------------------------------------------------

@test "reboot-check: sends status=up when /var/run/reboot-required absent" {
    rm -f /var/run/reboot-required
    run /usr/local/bin/uptime-kuma-reboot-check
    assert_success
    assert_output --partial "status=up"
}

@test "reboot-check: sends status=down when /var/run/reboot-required present" {
    touch /var/run/reboot-required
    run /usr/local/bin/uptime-kuma-reboot-check
    assert_success
    assert_output --partial "status=down"
    rm -f /var/run/reboot-required
}

# -- disk check ----------------------------------------------------------------

@test "disk-check: sends status=up when no filesystem is over threshold" {
    # The test machine should have disk space available; threshold defaults to 80%.
    # If the test machine is over 80%, this test will fail intentionally.
    run /usr/local/bin/uptime-kuma-disk-check
    assert_success
    assert_output --partial "status=up"
}
