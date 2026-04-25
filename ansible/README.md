# Ansible

Bootstraps the three apex nodes from fresh Ubuntu 24.04 to a working HA K3s
cluster. Roles are tiny and in-repo — no Galaxy dependencies.

## Prerequisites

- An `ansible` Python install on the workstation (`pipx install ansible-core`).
- The user `jake` exists on each target host and is in the `sudo` group.
- SSH key auth from the workstation to `jake@apex.devNN` (one-time
  `ssh-copy-id apex.devNN` per host if not already there).

## First run (fresh hosts)

The first run sets up NOPASSWD sudo and installs K3s. Sudo will still prompt
the first time:

```bash
cd ansible
ansible-playbook bootstrap.yml --ask-become-pass
```

After this, NOPASSWD is in place and subsequent runs need no flags:

```bash
ansible-playbook bootstrap.yml
```

## What the playbook does

1. **common** — apt update, baseline packages, enables `chrony` for time sync.
2. **sudoers** — drops `/etc/sudoers.d/90-jake-nopasswd`, validated via
   `visudo`.
3. **k3s** —
   - On `apex.dev01` (the `apex_bootstrap` group): runs the K3s installer
     with `--cluster-init` to start an embedded etcd cluster.
   - Slurps `/var/lib/rancher/k3s/server/node-token`.
   - On `apex.dev02` and `apex.dev03` (the `apex_joiners` group): runs the
     installer with `--server https://192.168.1.50:6443` and the slurped
     token, joining the etcd cluster.

The K3s version is pinned in `group_vars/apex.yml` (`k3s_version`). To
upgrade, bump that value and re-run.

## Adding a new node

1. Add the host to `inventory.yml` under `apex` and `apex_joiners`.
2. `ssh-copy-id jake@<new-host>`.
3. `ansible-playbook bootstrap.yml --ask-become-pass --limit <new-host>`.

## Tailscale subnet router

`apex.dev01` advertises the LAN (`192.168.1.0/24`) onto the tailnet so
phones/laptops off-network can reach LAN services by their `192.168.x.x`
address. The role installs Tailscale, enables IP forwarding, and brings
the node up.

**First run (one-time):**

1. Generate a one-off auth key at
   <https://login.tailscale.com/admin/settings/keys>. Recommended:
   non-reusable, non-ephemeral, default expiry. Copy the `tskey-auth-...`
   value.
2. Run the playbook with the key in the environment:

   ```bash
   TAILSCALE_AUTHKEY=tskey-auth-... ansible-playbook bootstrap.yml --limit apex_subnet_router
   ```

3. Approve the subnet route in the Tailscale admin console:
   <https://login.tailscale.com/admin/machines> → click `apex.dev01` →
   **Edit route settings** → tick `192.168.1.0/24` → **Save**. Until you
   do this, the route is advertised but not active.
4. (Optional) On the same machine page, **Disable key expiry** so the
   subnet router doesn't drop off the tailnet every 180 days.

**On client devices** (iPhone, MacBook, etc.): in the Tailscale app,
enable **Use Tailscale subnets** (sometimes shown as "Use exit nodes &
subnet routes"). Then `http://192.168.1.50` etc. resolves from anywhere
on the tailnet.

**Re-runs:** no auth key needed. The role uses `tailscale set` to
reconcile routes/hostname.
