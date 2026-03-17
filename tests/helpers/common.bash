# Shared helpers for ansible-webserver-hardening tests.
# Load with: load 'helpers/common.bash'

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
ROLE_ROOT="$REPO_ROOT/roles/uptime_kuma_hooks"
