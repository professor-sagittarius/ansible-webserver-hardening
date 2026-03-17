#!/usr/bin/env bats
# Tier 1: Static analysis - no running stack required.

setup() {
    load 'lib/bats-support/load'
    load 'lib/bats-assert/load'
    load 'helpers/common.bash'
}

# -- apt-hook.j2 ---------------------------------------------------------------

@test "apt-hook.j2: exists" {
    [[ -f "$ROLE_ROOT/templates/apt-hook.j2" ]]
}

@test "apt-hook.j2: references the uptime_kuma_unattended_upgrades_push_url variable" {
    run grep -q "uptime_kuma_unattended_upgrades_push_url" \
        "$ROLE_ROOT/templates/apt-hook.j2"
    assert_success
}

@test "apt-hook.j2: contains curl invocation" {
    run grep -q "curl" "$ROLE_ROOT/templates/apt-hook.j2"
    assert_success
}

@test "apt-hook.j2: uses DPkg::Post-Invoke" {
    run grep -q "DPkg::Post-Invoke" "$ROLE_ROOT/templates/apt-hook.j2"
    assert_success
}
