---
draft: true
date: 2026-10-13
comments: true
categories:
  - homelab
  - networking
---

# Self-Hosting Tailscale with Headscale

Tailscale is one of the few products that feels like magic to me. Install it on two devices and they can reach each other from anywhere over WireGuard, through NATs and firewalls. But that depends on a coordination server that handles key exchange, node enrollment, and ACLs, and by default that server runs in Tailscale's cloud.

Headscale is an open-source reimplementation of that server. I run it on my VPS, so all of the mesh's enrollment data, connection logs, and policy stay on hardware I control. This post covers what that gets me, what it costs, and where things currently stand.

<!-- more -->

## What changes and what doesn't

With Headscale, every device (laptops, phones, VMs) still runs the normal Tailscale client, just pointed at your own coordination URL. The WireGuard mesh and NAT traversal work the same as before. You take over node enrollment (through the CLI), ACL policy (a HuJSON file), and relaying.

In my setup Headscale shares the VPS with HAProxy, which routes `vpn.<domain>` traffic to it by SNI. The mesh is what makes the [three-tier ingress design](haproxy-chokepoint.md) work. HAProxy's backends are Tailscale addresses rather than home IP addresses, so my home network doesn't accept any inbound connections from the internet.

## Don't skip the DERP relay

Tailscale prefers direct peer-to-peer WireGuard connections, but some NAT setups, like carrier-grade NAT or strict corporate firewalls, can't be traversed. In those cases traffic falls back to a DERP relay. If you self-host coordination you should self-host a relay too, or those peers won't be able to connect. Headscale has a built-in DERP server that you enable with a config block, and the relay map is sent to clients automatically. The relay only forwards encrypted packets, so even as the operator you can't read the traffic.

## The bug that ate a weekend

When mesh routing misbehaves, suspect the client before your own config. I lost hours to a macOS Tailscale bug where Headscale accepted subnet routes advertised by a Mac but didn't re-propagate them after reconnects. These are the commands I used to track it down:

```bash
headscale nodes list          # enrollment + last-seen
tailscale ping <node>         # coordination-layer reachability
tailscale ping --tsmp <node>  # protocol-level connectivity
ip route show table 52        # what routes actually got installed
watch -n 0.5 tailscale status # direct vs. relayed, live
```

The fix was to change the architecture. I stopped using a Mac as a subnet router and had a Linux VM on the same subnet advertise the routes instead. Check the Tailscale GitHub issues before assuming your Headscale config is wrong.

## The ACLs are currently off

Headscale supports Tailscale-style ACLs, and I wrote a proper group-based policy matrix, but it's disabled and a permissive policy is active instead. The problem is upstream. pfSense runs on FreeBSD, where Tailscale can't disable SNAT on subnet routes, so LAN traffic routed through the mesh loses its real source IP at the router. ACLs can't match on source IPs that have been rewritten. Until that's fixed, network-level enforcement comes from VLAN firewall rules and the SSO layer, and the mesh isn't zero-trust yet. At least it's written down as a tracked issue instead of being forgotten.

## What you give up compared to managed Tailscale

- **MagicDNS.** I already run my own DNS (Unbound local zones), so I don't miss it.
- **The admin web UI.** Everything is done with `headscale` CLI commands, which is fine for one person.
- **New features.** New Tailscale client features sometimes take a while to get Headscale support.
- **Funnel and other hosted features.** My public ingress is HAProxy, so I don't need them.

## Who should run it

If you already self-host a lot of infrastructure, Headscale only adds one more systemd service and an occasional version upgrade. In exchange, the record of every device you own and when it connects stays with you. If you just want it to work with no maintenance, pay for Tailscale. The free tier is generous and the product is excellent. This whole homelab is about owning the stack, though, so Headscale was an easy choice for me.
