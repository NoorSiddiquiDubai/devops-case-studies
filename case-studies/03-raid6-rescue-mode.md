# Case Study 03 — Rescue-Mode RAID 6 Lockout Recovery (sshd StrictModes Root Cause)

## Problem

A bare-metal server running Ubuntu 22.04 with a 6-disk RAID 6 array (`/dev/md0`) became unreachable via SSH after a routine `apt upgrade`. The server was healthy (ping responded, services answered on application ports), but all SSH login attempts returned `Permission denied (publickey)` immediately — no password fallback offered.

Remote console was unavailable; the only access path was a physical KVM crash-cart at the datacenter.

## Action

### Step 1 — Rescue-mode access via KVM

Rebooted into Ubuntu rescue mode (GRUB → "Advanced options" → "Recovery mode" → "root shell with networking"). Mounted the root filesystem read-write:

```bash
mount -o remount,rw /
```

### Step 2 — Reproduce the error

Ran `sshd` in debug mode against the live config:

```bash
/usr/sbin/sshd -T 2>&1 | grep -i strict
# Output: StrictModes yes
```

Then manually tested the affected user's home directory:

```bash
ls -ld /home/deploy
# drwxrwxr-x 5 deploy deploy 4096 Oct 15 03:12 /home/deploy
#            ^^^ group-writable — sshd rejects this when StrictModes=yes
```

`apt upgrade` had run a post-install script for a monitoring agent that added the `deploy` user to a new group and reset the home directory permissions to `775` (group-writable). OpenSSH's `StrictModes yes` (default) rejects `authorized_keys` when the home directory or `.ssh` directory is group- or world-writable.

### Step 3 — Fix

```bash
chmod 750 /home/deploy
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys
```

Restarted `sshd` and verified from a second terminal (still in rescue shell) before closing the rescue session:

```bash
systemctl restart ssh
ssh -i ~/.ssh/id_ed25519 deploy@127.0.0.1 'echo OK'
# OK
```

### Step 4 — Prevent recurrence

Added an Ansible task to the server-hardening playbook:

```yaml
- name: Enforce SSH-safe home directory permissions
  file:
    path: "/home/{{ item }}"
    mode: "0750"
    state: directory
  loop: "{{ ssh_users }}"
```

Added a post-`apt` hook (`/etc/apt/apt.conf.d/99-ssh-perms`) to re-apply permissions after upgrades:

```bash
DPkg::Post-Invoke { "chmod 750 /home/deploy /home/deploy/.ssh 2>/dev/null || true"; };
```

## Evidence

- Root cause confirmed: `sshd -ddd` (debug level 3) log line: `Authentication refused: bad ownership or modes for directory /home/deploy`
- Fix applied in rescue shell; SSH access restored in < 8 min from KVM connection.
- Ansible playbook re-run on all 4 nodes in the cluster: 0 permission drift found on others.

## Result

SSH access restored without data loss or RAID degradation. The root cause (sshd `StrictModes` + package-manager permission reset) is now caught automatically by the post-apt hook and Ansible drift check.

---
*Names, IPs, domains, and tokens are placeholders.*
