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
echo "Next steps:"
echo
echo "  1. Create the vault for passwords:"
echo "     mkdir -p group_vars/all"
echo "     ansible-vault create group_vars/all/vault.yml"
echo "     # Add: admin_password: \"your-secure-password\""
echo
echo "  2. Edit inventory to configure users and settings:"
echo "     vim inventory_localhost.yml"
echo
echo "  3. Run the playbook:"
echo "     # Localhost deployment:"
echo "     ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --ask-vault-pass"
echo
echo "     # Remote host deployment:"
echo "     ansible-playbook -i inventory_remote.yml playbook_remote.yml --ask-vault-pass"
