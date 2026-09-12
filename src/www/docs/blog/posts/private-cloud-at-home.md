---
draft: true
date: 2026-09-01
comments: true
categories:
  - homelab
  - overview
---

# Building a Private Cloud at Home

A few years ago I started wondering how much of my digital life could run on hardware I own. It turned out to be almost all of it: identity, monitoring, home automation, game streaming, and remote access. It all runs on two Proxmox hosts in a closet, with a $5 VPS handling public traffic.

This post is an overview, and later posts cover each layer in more detail. Everything described here is in a public repo at [github.com/babraham123/homelab](https://github.com/babraham123/homelab), and the whole system deploys with one command.

<!-- more -->

## Ground rules

Every homelab is shaped by its constraints. These are mine:

1. **Reproducible from git.** If a machine dies, the repo plus one encryption key can rebuild it. There are no hand-configured servers and no settings I clicked through in a web UI two years ago and forgot about.
2. **No cloud dependencies,** with one exception: a cheap VPS that serves as the public endpoint, because residential ISPs and CGNAT make hosting directly from home miserable.
3. **Low power use.** The always-on hardware draws about 15-20 W. The larger machine is turned on when it's needed and stays off otherwise.

## The hardware

**pve1** is a fanless mini PC from AliExpress with a Celeron N5105, 32 GB of RAM, and four 2.5 GbE Intel NICs. It runs 24/7 and hosts the router VM, identity, monitoring, and home automation. It also holds the trust roots (certificate authorities and secrets keys), so it's the most locked-down machine in the system.

**pve2** is a custom tower with an i5-13500, an RTX 3060 Ti for the Windows gaming VM, a Tesla P4 for the voice pipeline, and a Coral TPU for camera object detection. It idles around 30 W, but it's usually turned off. An OliveTin button wakes it up when I want to play games or need the GPU.

**vpn** is the smallest Linode instance available, and it's the only machine with a public IP.

## How it fits together

```mermaid
flowchart TB
    inet(("Internet"))
    subgraph vps["Linode VPS (public IP)"]
        haproxy["HAProxy :80/:443<br/>SNI routing, rate limiting"]
        headscale["Headscale + DERP"]
    end
    subgraph home["Home network"]
        subgraph pve1["pve1: mini PC, always on"]
            router["router VM (pfSense)"]
            secsvcs["secsvcs VM<br/>identity + observability"]
            homesvcs["homesvcs VM<br/>home automation"]
        end
        subgraph pve2["pve2: tower, on demand"]
            websvcs["websvcs VM<br/>web apps"]
            gaming["gaming VM<br/>Windows + GPU"]
            pbs["Proxmox Backup Server"]
        end
    end
    inet --> haproxy
    haproxy -- "WireGuard mesh" --> secsvcs
    haproxy -- "WireGuard mesh" --> homesvcs
    haproxy -- "WireGuard mesh" --> websvcs
```

There are six VMs, and each one has a single job: `router` (pfSense, with all four physical NICs passed through over PCI), `secsvcs` (Authelia, LLDAP, and the metrics stack), `homesvcs` (Home Assistant, MQTT, and Zigbee), `websvcs` (user-facing apps), `devtop` (a Linux desktop), and `gaming` (Windows with GPU passthrough).

I use VMs instead of running containers directly on the host to limit the damage when something goes wrong. Each VM has its own Traefik ingress, container subnet, and snapshot schedule, so a bad deploy or a compromise stays inside one VM.

The three VMs that run containers host about 30 services as Podman quadlets, which are systemd unit files that run containers. There's no Kubernetes and no Compose daemon. That decision gets [its own post](podman-quadlets.md).

## How traffic gets in

Public requests pass through three layers:

1. **HAProxy on the VPS** reads the TLS SNI and routes the still-encrypted stream. It never terminates TLS. Rate limiting and geo-blocking also happen here.
2. **A WireGuard mesh** (self-hosted Headscale) carries traffic from the VPS to the VMs at home. The home network never accepts inbound connections directly.
3. **Traefik on each VM** terminates TLS and requires SSO before a request reaches any service.

Inside the house, split-horizon DNS lets Unbound resolve the same hostnames directly to the VMs, so internal traffic never goes through the VPS. The same URL works both at home and away.

## One command to deploy

The repo is built from Jinja2 templates. `render_src.sh` fills in variables from a single `vars.yml`, and a set of parse scripts generate the repetitive parts: DNS records from Traefik routes, metrics scrape targets from service configs, and sudoers entries from the command whitelist. Validation (YAML lint and duplicate-IP checks) runs first, and then `deploy_src.sh` pushes everything to every node.

Secrets are committed to git too. They're encrypted with SOPS and AGE and only decrypted in memory when a container starts. There's no Ansible and there are no agents. Remote automation goes through an SSH forced-command dispatcher that can only run a whitelisted set of actions. Both of these will get their own posts.

## Known gaps

This isn't a zero-trust network yet. I wrote a group-based Headscale ACL matrix, but it's disabled because a FreeBSD SNAT limitation rewrites source IPs on subnet routes. For now the mesh policy is permissive, and the real enforcement comes from VLAN firewall rules and the SSO layer. Wired VLAN segmentation is waiting on a managed switch. Backups cover VM disks but don't support file-level restores yet.

Writing down the gaps turned out to be as useful as documenting the architecture. About half of them became tracked issues with actual plans.

## Coming up

The rest of this series covers individual layers in detail: quadlets, SSO, secrets, the HAProxy edge, Headscale, VLANs and mDNS (in two posts, the second being a debugging story), observability, and streaming games from a headless VM.
