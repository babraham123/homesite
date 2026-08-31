---
draft: true
date: 2026-10-13
comments: true
categories:
  - homelab
  - networking
---

# Self-Hosting Tailscale with Headscale

Tailscale is one of the few products I'd call genuinely magical: install it on two devices and they can reach each other from anywhere, through NATs and firewalls, over WireGuard. But the magic has a coordination server behind it — key exchange, node enrollment, ACLs — and by default that server is Tailscale's cloud.

Headscale is the open-source reimplementation of that server. I run it on my VPS, which means the entire mesh — enrollment data, connection logs, policy — lives on hardware I control. Here's what that buys, what it costs, and the state of things honestly told.

<!-- more -->

## What changes, what doesn't

With Headscale you keep the normal Tailscale client on every device — laptops, phones, VMs — just pointed at your own coordination URL. The WireGuard mesh, NAT traversal, all of it works the same. What you take over: node enrollment (CLI), ACL policy (a HuJSON file), and relaying.

In my setup Headscale shares the VPS with HAProxy, which routes `vpn.<domain>` traffic to it by SNI. The mesh is what makes the whole [three-tier ingress design](haproxy-chokepoint.md) work: HAProxy's backends aren't home IP addresses — they're Tailscale addresses, so my home network accepts zero inbound connections from the internet.

## The DERP relay: don't skip it

Tailscale prefers direct peer-to-peer WireGuard, but some NAT combinations (carrier-grade NAT, strict corporate firewalls) can't be punched through. When that happens, traffic falls back to a DERP relay — and if you self-host coordination, you should relay too, or those peers simply can't connect. Headscale embeds a DERP server; enabling it is a config block, and the relay map distributes to clients automatically. The relay only forwards encrypted packets — even as its operator you can't read the traffic passing through.

## The bug that ate a weekend

A warning from experience: when mesh routing misbehaves, suspect the client before your config. I lost hours to a macOS Tailscale bug where subnet routes advertised by a Mac were accepted by Headscale but silently not re-propagated after reconnects. The diagnosis toolkit, for future reference:

```bash
headscale nodes list          # enrollment + last-seen
tailscale ping <node>         # coordination-layer reachability
tailscale ping --tsmp <node>  # protocol-level connectivity
ip route show table 52        # what routes actually got installed
watch -n 0.5 tailscale status # direct vs. relayed, live
```

The fix was architectural: don't use a Mac as a subnet router; a Linux VM on the same subnet advertises the routes instead. Check the Tailscale GitHub issues *before* assuming your Headscale config is wrong.

## Honest state: the ACLs are off

Headscale supports Tailscale-style ACLs, and I wrote a proper group-based policy matrix — which is currently disabled, with a permissive policy active. The blocker is upstream: pfSense runs on FreeBSD, where Tailscale can't disable SNAT on subnet routes, so LAN traffic routed through the mesh loses its real source IP at the router — and ACLs can't match on source IPs that have been rewritten. Until that lands, network-layer enforcement comes from VLAN firewall rules and the SSO layer, and the "zero-trust mesh" remains aspirational. It's written down as a tracked issue rather than quietly forgotten, which I've decided counts as engineering.

## What you give up vs. managed Tailscale

- **MagicDNS** — I run my own DNS anyway (Unbound local zones), so no loss here.
- **The admin web UI** — everything is `headscale` CLI commands. Fine for one operator.
- **Feature lag** — new Tailscale client features sometimes wait on Headscale support.
- **Funnel and other SaaS-side features** — my public ingress is HAProxy, so not missed.

## Verdict

If you're already self-hosting a pile of infrastructure, Headscale's marginal cost is one more systemd service and an occasional version bump — and in exchange, the map of every device you own and when it connects stays yours. If you just want the magic with zero operations, pay Tailscale; the free tier is generous and the product is excellent. For this homelab, whose entire premise is owning the stack, the choice made itself.
