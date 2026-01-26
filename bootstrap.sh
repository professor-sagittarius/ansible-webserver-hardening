#!/bin/bash
# ansible-webserver-hardening bootstrap script
# Installs Ansible and required collections/roles on fresh Debian installations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== Ansible Bootstrap Script ==="
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Install Ansible
if ! command -v ansible &> /dev/null; then
    echo "Installing Ansible..."
    apt-get update
    apt-get install -y ansible python3-pip
else
    echo "Ansible already installed: $(ansible --version | head -1)"
fi

# Install required collections and roles
echo
echo "Installing Ansible collections..."
ansible-galaxy collection install -r "$SCRIPT_DIR/requirements.yml"

echo
echo "Installing Ansible roles..."
ansible-galaxy role install -r "$SCRIPT_DIR/requirements.yml"

echo
echo "=== Bootstrap complete ==="
echo
echo "Available playbooks:"
ls -1 "$SCRIPT_DIR"/playbook_*.yml | xargs -n1 basename | sed 's/^/  - /'
echo
echo "Example usage:"
echo "  # Localhost deployment:"
echo "  ansible-playbook -i inventory_localhost.yml playbook_localhost.yml"
echo
echo "  # Remote host deployment:"
echo "  ansible-playbook -i inventory_remote.yml playbook_remote.yml"
