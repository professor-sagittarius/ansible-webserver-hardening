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

# -- reboot-check.sh.j2 --------------------------------------------------------

@test "reboot-check.sh.j2: exists" {
    [[ -f "$ROLE_ROOT/templates/reboot-check.sh.j2" ]]
}

@test "reboot-check.sh.j2: references the push URL variable" {
    run grep -q "uptime_kuma_reboot_push_url" \
        "$ROLE_ROOT/templates/reboot-check.sh.j2"
    assert_success
}

@test "reboot-check.sh.j2: checks /var/run/reboot-required" {
    run grep -q "reboot-required" "$ROLE_ROOT/templates/reboot-check.sh.j2"
    assert_success
}

@test "reboot-check.sh.j2: sends status=down when reboot needed" {
    run grep -q "status=down" "$ROLE_ROOT/templates/reboot-check.sh.j2"
    assert_success
}

@test "reboot-check.sh.j2: sends status=up when no reboot needed" {
    run grep -q "status=up" "$ROLE_ROOT/templates/reboot-check.sh.j2"
    assert_success
}

# -- disk-check.sh.j2 ----------------------------------------------------------

@test "disk-check.sh.j2: exists" {
    [[ -f "$ROLE_ROOT/templates/disk-check.sh.j2" ]]
}

@test "disk-check.sh.j2: references the push URL variable" {
    run grep -q "uptime_kuma_disk_push_url" \
        "$ROLE_ROOT/templates/disk-check.sh.j2"
    assert_success
}

@test "disk-check.sh.j2: references the threshold variable" {
    run grep -q "uptime_kuma_disk_threshold_percent" \
        "$ROLE_ROOT/templates/disk-check.sh.j2"
    assert_success
}

@test "disk-check.sh.j2: sends status=down on high usage" {
    run grep -q "status=down" "$ROLE_ROOT/templates/disk-check.sh.j2"
    assert_success
}

@test "disk-check.sh.j2: sends status=up on normal usage" {
    run grep -q "status=up" "$ROLE_ROOT/templates/disk-check.sh.j2"
    assert_success
}
