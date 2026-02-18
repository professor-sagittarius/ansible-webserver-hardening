# ansible-webserver-hardening

Modular Ansible roles for provisioning and hardening Debian 12 (Bookworm) and Debian 13 (Trixie) web servers.

## Quick Start

Clone and install dependencies:

```bash
git clone https://github.com/professor-sagittarius/ansible-webserver-hardening.git
cd ansible-webserver-hardening
sudo ./bootstrap.sh
```

Create the vault for passwords:

```bash
mkdir -p group_vars/all
ansible-vault create group_vars/all/vault.yml
# Add: admin_password: "your-secure-password"
```

Edit inventory to configure users and settings:

```bash
vim inventory_localhost.yml
```

Run the playbook:

```bash
ansible-playbook -i inventory_localhost.yml playbook.yml --ask-vault-pass
```

## Requirements

- Debian 12 (Bookworm) or Debian 13 (Trixie)
- Root access
- Internet connection (for package installation)

## Vault Setup

Sensitive data (passwords) should be stored in an encrypted vault file. The playbook expects passwords to be defined in `group_vars/all/vault.yml`.

### Create or edit the vault

```bash
# Create the directory (if it doesn't exist)
mkdir -p group_vars/all

# Create a new vault
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
ansible-playbook -i inventory_localhost.yml playbook.yml --ask-vault-pass
```

**Note:** The vault file is not included in the repository (it's in `.gitignore`). You must create it after cloning.

## Roles

### Local Roles

| Role | Description |
|------|-------------|
| `docker` | Install Docker via geerlingguy.docker, plus Portainer/Dockge. Configures daemon.json for log rotation. |
| `disk_resize` | Expand partition and filesystem to use all available disk space |
| `guest_agent` | Install QEMU guest agent (for Proxmox/KVM VMs) |
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
3. **Base system configuration** - Disk resize (if enabled), QEMU guest agent
4. **Docker installation** - Docker, Compose, daemon.json log rotation, Portainer/Dockge
5. **Security hardening** - Firewall, fail2ban, ClamAV, cron, OS hardening, SSH hardening

### Firewall and Docker

The firewall only opens port 22 (SSH) by default. Docker manages its own iptables rules that bypass the host firewall, so Docker-exposed service ports do not need firewall rules.

### Lockout Prevention

The `ssh_preflight` role runs before SSH hardening and **fails the playbook** if the configuration would cause lockout:

- **Disabling root login** requires at least one sudo user with SSH authorized_keys
- **Disabling password auth** requires at least one user (including root) with SSH authorized_keys

The users role runs before ssh_preflight, so users defined in `users_user_list` will be created first.

### Configuration

See `all_variables.yml` for a complete reference of all configurable variables.

## Examples

### Localhost Deployment

```bash
ansible-vault edit group_vars/all/vault.yml  # Set admin_password
vim inventory_localhost.yml                   # Configure settings
ansible-playbook -i inventory_localhost.yml playbook.yml --ask-vault-pass
```

### Remote Host Deployment

```bash
vim inventory_remote.yml  # Add your hosts and user config
ansible-playbook -i inventory_remote.yml playbook.yml --ask-vault-pass
```

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory_localhost.yml playbook.yml --check --ask-vault-pass
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
├── playbook.yml               # Main playbook (localhost and remote)
└── roles/
    ├── docker/
    ├── disk_resize/
    ├── guest_agent/
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
- The playbook automatically configures `net.ipv4.ip_forward: 1` via sysctl
- Docker manages its own iptables rules; the host firewall does not need to open Docker service ports
