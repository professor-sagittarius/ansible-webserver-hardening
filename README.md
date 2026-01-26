# ansible-webserver-hardening

Modular Ansible roles for provisioning and hardening Debian 12 (Bookworm) and Debian 13 (Trixie) web servers.

## Quick Start

```bash
# On a fresh Debian machine
git clone https://github.com/professor-sagittarius/ansible-webserver-hardening.git
cd ansible-webserver-hardening
sudo ./bootstrap.sh

# Edit inventory to configure users and settings
vim inventory_localhost.yml

# Run playbook
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml
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

## Roles

### Local Roles

| Role | Description |
|------|-------------|
| `ssh` | Install OpenSSH server and generate host keys |
| `docker` | Install Docker via geerlingguy.docker, plus Portainer |
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
| `devsec.hardening.ssh_hardening` | SSH server hardening |
| `geerlingguy.docker` | Docker installation (wrapped by local docker role) |
| `geerlingguy.firewall` | iptables-based firewall |
| `robertdebock.fail2ban` | Intrusion prevention (brute-force protection) |
| `geerlingguy.clamav` | Antivirus scanning |
| `robertdebock.cron` | Cron daemon management |

## Execution Phases

1. **User setup** - Creates users with sudo/docker groups and SSH keys
2. **SSH lockout prevention check** - Validates safe to harden
3. **Base system configuration** - SSH, disk resize, guest agent, hostname
4. **Docker installation** - Docker, Compose, Portainer
5. **Security hardening** - OS hardening, SSH hardening, firewall, fail2ban, ClamAV, cron
6. **Network configuration** - Static IP (if enabled)

## Configuration

### User Management

Users are managed via `robertdebock.users`. Define users in the inventory:

```yaml
users_user_list:
  - name: admin
    comment: "Admin User"
    group: admin
    groups: sudo,docker
    password: "{{ 'mypassword' | password_hash('sha512') }}"
    authorized_keys:
      - "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5... admin@workstation"

  - name: olduser
    state: absent  # Removes user
```

**Note:** Docker group membership is managed here via `groups: sudo,docker`, not via `docker_users`.

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

      # Users (robertdebock.users)
      users_user_list:
        - name: admin
          groups: sudo,docker
          authorized_keys:
            - "ssh-ed25519 AAAAC3..."

      # Hostname
      change_hostname: true
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
vim inventory_localhost.yml
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml
```

### Remote Host Deployment

```bash
vim inventory_remote.yml  # Add your hosts
ansible-playbook -i inventory_remote.yml playbook_remote.yml
```

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory_localhost.yml playbook_localhost.yml --check
```

## File Structure

```
ansible-webserver-hardening/
├── ansible.cfg
├── bootstrap.sh
├── requirements.yml
├── all_variables.yml          # Complete variable reference
├── inventory_localhost.yml    # Localhost inventory
├── inventory_remote.yml       # Remote hosts inventory
├── playbook_localhost.yml     # Localhost playbook
├── playbook_remote.yml        # Remote playbook
└── roles/
    ├── ssh/
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
- Ensure `users_user_list` includes a user with `groups: sudo` and `authorized_keys`
- Or set `ssh_permit_root_login: 'yes'` for initial setup

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
