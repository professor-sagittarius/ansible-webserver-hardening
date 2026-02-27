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

Create your local inventory from the example template:

```bash
cp inventory_localhost.yml.example inventory_localhost.yml
vim inventory_localhost.yml
```

> `inventory_localhost.yml` is gitignored - it contains your SSH keys and host-specific settings. Never commit it.

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
| `base` | Essential packages, unattended security updates, swap (optional), NTP verification |
| `docker` | Install Docker via geerlingguy.docker, plus optional Portainer/Dockge. Configures daemon.json. |
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
| `robertdebock.cron` | Cron daemon management |

## Execution Phases

1. **User setup** - Creates groups and users with sudo/docker access and SSH keys
2. **SSH lockout prevention check** - Validates safe to harden
3. **Base system configuration** - Disk resize (if enabled), QEMU guest agent, essential packages, unattended upgrades
4. **Docker installation** - Docker, Compose, daemon.json (log rotation, live-restore, no-new-privileges), optional Portainer/Dockge
5. **Security hardening** - Firewall, fail2ban, cron, OS hardening, SSH hardening

### Firewall and Docker

The firewall only opens port 22 (SSH) by default. Docker manages its own iptables rules that bypass the host firewall, so Docker-exposed service ports do not need firewall rules.

**Important:** Because Docker bypasses the host firewall, any port exposed by a container (`ports:` in a compose file) is reachable from the network regardless of `firewall_allowed_tcp_ports`. If you enable Portainer or Dockge, restrict their ports using `portainer_bind_address` / `dockge_bind_address` (see below).

### Portainer and Dockge - Attack Surface Warning

Both Portainer and Dockge mount `/var/run/docker.sock`, which grants **root-equivalent access to the host**. A compromise of either UI is equivalent to root shell access.

Both are **disabled by default** (`install_portainer: false`, `install_dockge: false`). If you enable either:

1. **Restrict the bind address** to your LAN IP or `127.0.0.1` in inventory:
   ```yaml
   install_portainer: true
   portainer_bind_address: "192.168.1.x"   # your server's LAN IP
   # or for localhost-only + SSH tunnel access:
   portainer_bind_address: "127.0.0.1"
   ```
2. **Do not expose ports 8000, 9443 (Portainer) or 5001 (Dockge) to the internet.** With Cloudflare Tunnel handling external traffic, these ports should never be publicly reachable.
3. **Keep the image pinned** (`portainer_version`) and update it deliberately rather than using `:latest`.

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
ansible-vault edit group_vars/all/vault.yml      # Set admin_password
vim inventory_localhost.yml                       # Configure settings
ansible-playbook -i inventory_localhost.yml playbook.yml --ask-vault-pass
```

### Remote Host Deployment

```bash
cp inventory_remote.yml.example inventory_remote.yml
vim inventory_remote.yml                          # Add your hosts and user config
ansible-playbook -i inventory_remote.yml playbook.yml --ask-vault-pass
```

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory_localhost.yml playbook.yml --check --ask-vault-pass
```

## Post-Provisioning Playbooks

Targeted playbooks for common operational tasks - no need to re-run the full playbook:

| Playbook | Usage |
|---|---|
| `playbooks/add-user.yml` | Add a new user with SSH keys to an already-hardened server |
| `playbooks/resize-disk.yml` | Expand partition/filesystem after growing a Proxmox disk |
| `playbooks/update-system.yml` | Apply all available package updates; report if reboot required |
| `playbooks/security-compliance.yml` | Re-apply or drift-check the DevSec hardening roles only |

```bash
# Add a user
ansible-playbook -i inventory_localhost.yml playbooks/add-user.yml --ask-vault-pass \
  -e "new_user=alice new_user_ssh_key='ssh-ed25519 AAAA...'"

# Resize disk after expanding it in Proxmox
ansible-playbook -i inventory_localhost.yml playbooks/resize-disk.yml

# Update packages (add -e reboot_if_required=true to auto-reboot if needed)
ansible-playbook -i inventory_localhost.yml playbooks/update-system.yml

# Check for security configuration drift without making changes
ansible-playbook -i inventory_localhost.yml playbooks/security-compliance.yml --check --ask-vault-pass

# Re-enforce security hardening after manual changes
ansible-playbook -i inventory_localhost.yml playbooks/security-compliance.yml --ask-vault-pass
```

## Dependency Updates

External roles and collections are version-pinned in `requirements.yml`. A GitHub Actions workflow (`.github/workflows/galaxy-updates.yml`) runs every Monday and opens a pull request automatically if any role or collection has a newer version available on Ansible Galaxy.

Before merging a dependency update PR, review the upstream changelog and test the playbook against a fresh VM. Pay particular attention to `devsec.hardening` where major version bumps may include breaking changes.

## File Structure

```
ansible-webserver-hardening/
├── .github/
│   └── workflows/
│       └── galaxy-updates.yml          # Weekly PR for role/collection version updates
├── ansible.cfg
├── bootstrap.sh
├── requirements.yml                    # Pinned role and collection versions
├── all_variables.yml                   # Complete variable reference
├── group_vars/
│   └── all/
│       └── vault.yml                   # Encrypted passwords (gitignored)
├── inventory_localhost.yml             # Gitignored - copy from *.example
├── inventory_localhost.yml.example     # Template - copy and edit
├── inventory_remote.yml                # Gitignored - copy from *.example
├── inventory_remote.yml.example        # Template - copy and edit
├── playbook.yml                        # Main provisioning playbook
├── playbooks/
│   ├── add-user.yml                    # Add a user post-provisioning
│   ├── resize-disk.yml                 # Expand disk post-provisioning
│   ├── security-compliance.yml         # Re-apply/drift-check DevSec roles
│   └── update-system.yml              # Apply package updates
└── roles/
    ├── base/                           # Essential packages, unattended upgrades, swap
    ├── docker/
    ├── disk_resize/
    ├── guest_agent/
    └── ssh_preflight/
```

External roles (`geerlingguy.*`, `robertdebock.*`) are fetched by `bootstrap.sh` and gitignored. They are version-pinned in `requirements.yml`. To update a role, change its version there and re-run `bootstrap.sh`.

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

**SSH "Permission denied" after hardening (ssh_allow_groups):**
- The playbook restricts SSH to the `sudo` group by default (`ssh_allow_groups: "sudo"`)
- Any user not in the `sudo` group will be denied SSH access even with a valid key
- To allow additional groups: set `ssh_allow_groups: "sudo yourgroupname"` in inventory
- To allow all users: set `ssh_allow_groups: ""` in inventory

**Docker networking broken after hardening:**
- The playbook automatically configures `net.ipv4.ip_forward: 1` via sysctl
- Docker manages its own iptables rules; the host firewall does not need to open Docker service ports

**Portainer/Dockge not accessible from LAN:**
- Check `portainer_bind_address` / `dockge_bind_address` - if set to `127.0.0.1`, access requires an SSH tunnel
- To access from LAN, set the bind address to the server's LAN IP in inventory
