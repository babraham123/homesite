---
date: 2026-10-07
comments: true
social:
  cards_layout_options:
    background_image: docs/img/blog/ssh-dispatcher-card.webp
    background_color: "#00000099"
image: ../../img/blog/ssh-dispatcher-card.webp
categories:
  - homelab
  - security
---

# Automation That Can't Run Arbitrary Commands: An SSH Forced-Command Dispatcher

A button in my homelab wakes a server, boots a Windows VM on it, and starts a game stream. That means running commands as root on three machines over SSH, and the key that does it can't run `rm -rf`, or even `ls`.

If you automate admin tasks across a handful of machines and don't want to run Ansible or hand out an SSH key that can do anything as root, this pattern is worth stealing. It's about 20 lines of sshd config and bash, and the sudo rules are generated from the same list as the commands, so the two can't drift apart.

<!-- more -->

<figure class="post-hero" markdown>
![A rust-colored steel footbridge over a rocky mountain river](../../img/blog/ssh-dispatcher.webp){ width="1600" height="900" loading="lazy" }
<figcaption>Photo by me on a recent trip. Narrowly scoped and a little sketchy, just the way I like my remote automation.</figcaption>
</figure>

## The problem

Plenty of things in the lab need root on another machine: deploying services, distributing certificates, running backups, and the buttons in OliveTin, a self-hosted web UI that turns shell commands into buttons. The usual answers didn't appeal to me:

- **A config-management tool** like Ansible or Salt. These either run an agent on every node or need broad root access to push changes, and they're a lot of machinery for nine nodes and one person.
- **SSH as root with a plain key.** It's simple, but the key ends up on the OliveTin VM and in deploy scripts. Whoever steals it owns every node.

What I wanted was a key that can trigger a fixed set of actions and nothing else.

## Two accounts

Every node has two admin accounts:

- **`manualadmin`** is for me. It's interactive and has full sudo, with a password.
- **`autoadmin`** is for automation. Every connection it makes is forced into a single script.

sshd enforces this constraint:

```
Match User autoadmin
    ForceCommand /usr/local/bin/dispatcher.sh
    AllowTcpForwarding no
    X11Forwarding no
    PermitTTY no
    AllowAgentForwarding no
    PermitTunnel no
```

`ForceCommand` makes sshd ignore whatever command the client asked to run. It runs the dispatcher instead and passes the original request along in the `$SSH_ORIGINAL_COMMAND` environment variable. The other lines turn off terminals, port forwarding, and tunnels, so the account can't be used as a jump host either.

## The dispatcher

The dispatcher is a `case` statement that matches the request against exact names. Here's a trimmed version of the one on pve2, the Proxmox host that runs the gaming VM:

```bash
case "${SSH_ORIGINAL_COMMAND:-}" in
  start_gaming_vm)
    sudo /root/homelab-rendered/src/pve2/commands.sh start_gaming_vm
    ;;
  backup)
    sudo /root/homelab-rendered/src/pve2/backup.sh
    ;;
  shutdown)
    sudo /usr/sbin/shutdown -h now
    ;;
  *)
    echo "Unauthorized command: '${SSH_ORIGINAL_COMMAND:-}'"
    exit 1
    ;;
esac
```

Automation calls it like a normal SSH command, `ssh autoadmin@pve2 start_gaming_vm`. Anything that isn't on the list gets logged and rejected. Commands don't take parameters, so no untrusted input ever gets interpolated into a shell.

## Sudoers generated from the same list

The dispatcher only works if `autoadmin`'s sudo access is just as strict. Broad sudo ruins the security model, and missing rules break the commands. So I don't write either file by hand.

Each node's services and commands are declared once in an inventory file, `src/nodes.yml`:

```yaml
pve2:
  commands:
    - {name: start_gaming_vm, script: pve2/commands.sh}
    - {name: stop_gaming_vm, script: pve2/commands.sh}
    - {name: backup, run: [sudo /root/homelab-rendered/src/pve2/backup.sh]}
```

At render time, a Jinja2 template turns that list into the dispatcher's `case` block, the node's sudoers file, and the OliveTin buttons. The sudoers file grants `autoadmin` passwordless sudo for exactly the command lines the dispatcher runs, and nothing else.

## One button, three hops

OliveTin's "start gaming" button runs this:

```bash
ssh autoadmin@router start_pve2 \
  && ssh autoadmin@pve2 start_gaming_vm \
  && ssh autoadmin@gaming StartSunshine
```

The router sends a wake-on-LAN packet to pve2, pve2 starts the Windows VM, and the VM starts Sunshine, the game-streaming server. Each hop is a separate whitelist on a separate machine. The router can wake pve2, but it can't start or stop VMs, and pve2 can't do anything inside Windows.

OliveTin adds its own layer on top. It reads group membership from my SSO login, denies everything by default, gives admins every button, and only shows the gaming buttons to everyone else.

## Windows too

The gaming VM runs OpenSSH, and the same `autoadmin` model works there with a PowerShell dispatcher that checks the request against a whitelist (`StartSunshine`, `StopSunshine`, and one setup command). The catch is that the Windows dispatcher doesn't run anything itself. Sunshine has to start in my logged-in desktop session, not in a background SSH session, so the dispatcher just drops a trigger file named `C:\SSH_Triggers\Homelab_<command>`. A small watcher running in the desktop session sees the file, runs the scheduled task with the same name, and deletes the trigger.

## Gotchas

**File uploads pass through.** Modern `scp` (OpenSSH 9 and later) uses the SFTP protocol, so the dispatcher lets the `sftp-server` binary through. I need this for distributing certificates and keys: new certs and SSH keys are copied into each node's `autoadmin` home directory, and a whitelisted root command moves them into place. This is the soft spot in the design. `autoadmin` can read and write files wherever `autoadmin` has permission, which is why that permission stops at its home directory and everything privileged goes through a whitelisted command.

**Host keys.** Automation can't answer a "do you trust this host?" prompt. Every node gets an SSH host certificate signed by the lab's own SSH certificate authority, so clients trust any host signed by it without ever seeing that prompt.

## Tradeoffs

- **Adding a remote action takes a deploy.** Every new command means a line in `nodes.yml` and a redeploy. That friction is deliberate.
- **There are no parameters.** Anything that needs input becomes one command per variant, or a command that reads a file.
- **It doesn't scale to a fleet.** This works well for nine nodes and one operator. A team managing hundreds of machines needs real config management.
- **The narrow sudo grant is the whole security model.** The tempting shortcut is to give `autoadmin` broader sudo "just for now". Doing that would quietly undo everything above.

## What a stolen key gets you

If someone steals the automation key, they can replay a fixed menu of actions that take no parameters: restart a service, start a VM, run a backup. That's annoying, but it's a much better worst case than root on every machine.

The pieces are in [the repo](https://github.com/babraham123/homelab): [`src/nodes.yml`](https://github.com/babraham123/homelab/blob/main/src/nodes.yml) is the inventory, `src/nodes.jinja` generates the dispatcher and sudoers files, and [`src/debian/autoadmin_sshd.conf`](https://github.com/babraham123/homelab/blob/main/src/debian/autoadmin_sshd.conf) has the sshd config. The design notes in [`docs/adr/`](https://github.com/babraham123/homelab/tree/main/docs/adr) (0005 and 0006) explain the reasoning.
