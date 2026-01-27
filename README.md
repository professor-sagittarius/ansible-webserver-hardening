# ansible-webserver-hardening

Modular Ansible roles for provisioning and hardening Debian 12 (Bookworm) and Debian 13 (Trixie) web servers.

## Quick Start

```bash
# On a fresh Debian machine
git clone https://github.com/professor-sagittarius/ansible-webserver-hardening.git
cd ansible-webserver-hardening
sudo ./bootstrap.sh

# Set up the vault with your password
ansible-vault edit group_vars/all/vault.yml
# Add: admin_password: "your-secure-password"

# Edit inventory to configure users and settings
vim inventory_localhost.yml

# Run playbook
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --ask-vault-pass
```

## Requirements

- Debian 12 (Bookworm) or Debian 13 (Trixie)
- Root access
- Internet connection (for package installation)

## Playbooks

| Playbook | Description |
|----------|-------------|
| `playbook_localhost.yml` | Hardened setup for localhost deployment |
| `playbook_remote.yml` | Hardened setup for remote host deployment |

Both playbooks install all components with security hardening enabled.

## Vault Setup

Sensitive data (passwords) should be stored in an encrypted vault file. The playbooks expect passwords to be defined in `group_vars/all/vault.yml`.

### Create or edit the vault

```bash
# Create a new vault (if it doesn't exist)
ansible-vault create group_vars/all/vault.yml

# Or edit an existing vault
ansible-vault edit group_vars/all/vault.yml
```

### Vault contents

```yaml
admin_password: "your-secure-password-here"
```

### Using the vault

Always run playbooks with `--ask-vault-pass`:

```bash
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --ask-vault-pass
```

Or use a vault password file:

```bash
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --vault-password-file ~/.vault_pass
```

**Note:** The vault file is not included in the repository (it's in `.gitignore`). You must create it after cloning.

## Roles

### Local Roles

| Role | Description |
|------|-------------|
| `docker` | Install Docker via geerlingguy.docker, plus Portainer/Dockge |
| `disk_resize` | Expand partition and filesystem to use all available disk space |
| `guest_agent` | Install QEMU guest agent (for Proxmox/KVM VMs) |
| `hostname` | Set system hostname |
| `network` | Configure static IP with netplan |
| `ssh_preflight` | Pre-flight checks to prevent SSH lockout during hardening |

### External Roles

| Role | Description |
|------|-------------|
| `robertdebock.users` | User and group management |
| `devsec.hardening.os_hardening` | Kernel and OS-level security hardening |
| `devsec.hardening.ssh_hardening` | SSH server hardening (includes OpenSSH installation) |
| `geerlingguy.docker` | Docker installation (wrapped by local docker role) |
| `geerlingguy.firewall` | iptables-based firewall |
| `robertdebock.fail2ban` | Intrusion prevention (brute-force protection) |
| `geerlingguy.clamav` | Antivirus scanning |
| `robertdebock.cron` | Cron daemon management |

## Execution Phases

1. **User setup** - Creates groups and users with sudo/docker access and SSH keys
2. **SSH lockout prevention check** - Validates safe to harden
3. **Base system configuration** - Disk resize, guest agent, hostname
4. **Docker installation** - Docker, Compose, Portainer
5. **Security hardening** - OS hardening, SSH hardening, firewall, fail2ban, ClamAV, cron
6. **Network configuration** - Static IP (if enabled)

## Configuration

### User Management

Users are managed via `robertdebock.users`. Define users in the inventory with passwords referenced from the vault:

```yaml
users_group_list:
  - name: docker

users_user_list:
  - name: admin
    groups:
      - sudo
      - docker
    password: "{{ admin_password | password_hash('sha512') }}"
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@workstation"
    expires: -1
```

**Important notes:**
- `groups` must be a YAML list, not a comma-separated string
- The `docker` group is created via `users_group_list` before the user is created
- Passwords reference vault variables using Jinja2 templates
- The `expires: -1` prevents password expiration

### SSH Hardening

```yaml
# Values: 'yes', 'no', 'prohibit-password', 'forced-commands-only'
ssh_permit_root_login: 'no'
ssh_password_authentication: false
```

### Lockout Prevention

The `ssh_preflight` role runs before SSH hardening and **fails the playbook** if the configuration would cause lockout:

- **Disabling root login** requires at least one sudo user with SSH authorized_keys
- **Disabling password auth** requires at least one user (including root) with SSH authorized_keys

The users role runs before ssh_preflight, so users defined in `users_user_list` will be created first.

### Inventory Variables

```yaml
all:
  hosts:
    localhost:
      ansible_connection: local
      ansible_python_interpreter: /usr/bin/python3

      # Groups to create (docker group needed before user creation)
      users_group_list:
        - name: docker

      # Users (robertdebock.users)
      users_user_list:
        - name: admin
          groups:
            - sudo
            - docker
          password: "{{ admin_password | password_hash('sha512') }}"
          authorized_keys:
            - "ssh-ed25519 AAAAC3..."
          expires: -1

      # Hostname
      change_hostname: false
      vm_hostname: "my-server"

      # Disk
      resize_disk: true
      disk_device: "/dev/sda"
      partition_number: 1

      # Network (static IP)
      configure_static_ip: false
      network_interface: "eth0"
      static_ip: "192.168.1.100/24"
      gateway_ip: "192.168.1.1"
      dns_servers:
        - "8.8.8.8"

      # SSH hardening
      ssh_permit_root_login: 'no'
      ssh_password_authentication: false
```

See `all_variables.yml` for a complete reference of all configurable variables.

## Examples

### Localhost Deployment

```bash
ansible-vault edit group_vars/all/vault.yml  # Set admin_password
vim inventory_localhost.yml                   # Configure settings
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --ask-vault-pass
```

### Remote Host Deployment

```bash
vim inventory_remote.yml  # Add your hosts and user config
ansible-playbook -i inventory_remote.yml playbook_remote.yml --ask-vault-pass
```

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --check --ask-vault-pass
```

## File Structure

```
ansible-webserver-hardening/
├── ansible.cfg
├── bootstrap.sh
├── requirements.yml
├── all_variables.yml          # Complete variable reference
├── group_vars/
│   └── all/
│       └── vault.yml          # Encrypted passwords (ansible-vault)
├── inventory_localhost.yml    # Localhost inventory
├── inventory_remote.yml       # Remote hosts inventory
├── playbook_localhost.yml     # Localhost playbook
├── playbook_remote.yml        # Remote playbook
└── roles/
    ├── docker/
    ├── disk_resize/
    ├── guest_agent/
    ├── hostname/
    ├── network/
    └── ssh_preflight/
```

## Troubleshooting

**"Permission denied" errors:**
- Ensure you're running with `become: true` or as root
- Check `ansible_user` has sudo access

**Collection or role not found:**
- Run `sudo ./bootstrap.sh` to install dependencies

**SSH lockout prevention failure:**
- Ensure `users_user_list` includes a user with `groups: [sudo]` and `authorized_keys`
- Or set `ssh_permit_root_login: 'yes'` for initial setup

**"Group X does not exist" error:**
- Add the group to `users_group_list` before referencing it in a user's `groups`
- Example: Add `- name: docker` to `users_group_list`

**Vault password errors:**
- Ensure you're using `--ask-vault-pass` when running playbooks
- Check that `group_vars/all/vault.yml` exists and contains the required password variables

**Docker networking broken after hardening:**
- The playbook automatically configures `net.ipv4.ip_forward: 1`
- Check firewall allows Docker ports

## Security Features

| Category | Implementation |
|----------|----------------|
| **OS Hardening** | Kernel parameters, filesystem restrictions, PAM policies |
| **SSH Hardening** | Strong ciphers, key-only auth (configurable), fail2ban protection |
| **Firewall** | iptables rules, only required ports open |
| **Intrusion Prevention** | Fail2ban with SSH jail enabled |
| **Antivirus** | ClamAV with automatic definition updates |
