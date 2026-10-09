---
date: 2026-08-08
comments: true
social:
  cards_layout_options:
    background_image: docs/img/blog/self-hosting-tailscale-headscale-card.webp
    background_color: "#00000080"
image: ../../img/blog/self-hosting-tailscale-headscale-card.webp
categories:
  - homelab
  - networking
---

# Self-Hosting Tailscale with Headscale

Tailscale is one of the few products that feels like magic to me. Install it on two devices and they can reach each other from anywhere over WireGuard, through NATs and firewalls. But that depends on a coordination server that handles key exchange, node enrollment, and ACLs, and by default that server runs in Tailscale's cloud.

Headscale is an open-source reimplementation of that server. I run it on my VPS, so all of the mesh's enrollment data, connection logs, and policy stay on hardware I control. Here's a look at my setup, the tradeoffs, and what's left to do.

<!-- more -->

<figure class="post-hero" markdown>
![A city skyline and ferry piers lit up at night](../../img/blog/self-hosting-tailscale-headscale.webp){ width="1600" height="900" loading="lazy" }
<figcaption>Photo by me: a cityscape from a recent trip. Thousands of independent lights, with one grid coordinating them all.</figcaption>
</figure>

## What changes and what doesn't

With Headscale, every device (laptops, phones, VMs) still runs the normal Tailscale client, just pointed at your own coordination URL. The WireGuard mesh and NAT traversal work the same as before. You take over node enrollment (CLI pre-auth keys, or SSO login through my identity provider), ACL policy (a HuJSON file), and relaying.

In my setup Headscale shares the VPS (vpnsvcs) with HAProxy, which routes `vpn.<domain>` traffic to it by SNI.

## A homemade Funnel

Tailscale Funnel lets a device on your tailnet accept traffic from the public internet, relayed through Tailscale's servers. Headscale doesn't have Funnel, so I built the equivalent on the VPS.

Besides Headscale, the VPS also runs a regular Tailscale client, logged in as a dedicated `public` user and started with `--accept-routes` so it can reach the home subnet. HAProxy takes public traffic on ports 80 and 443 and forwards it through that client into the tailnet. My home services are split across three VMs: secsvcs (identity and monitoring), homesvcs (home automation), and websvcs (web apps, including this site). Hostnames for secsvcs and homesvcs services go to those VMs, and everything else goes to websvcs, where Traefik passes the main site to the nginx container that serves it.

This is what makes the [three-layer ingress design](private-cloud-at-home.md#how-traffic-gets-in) work. My home network doesn't accept any inbound connections from the internet. Public traffic only gets in over the WireGuard tunnel that the VPS's client is part of. Since the mesh ACLs aren't enforced yet (more on that below), ufw on the VPS limits what that client can reach: outbound traffic on `tailscale0` is only allowed to ports 80 and 443 on those three VMs.

## Don't skip the DERP relay

Tailscale prefers direct peer-to-peer WireGuard connections, but you just can't punch through some NAT setups, like carrier-grade NAT or strict corporate firewalls. When that happens, traffic falls back to a DERP relay. If you self-host coordination, it's worth self-hosting a relay too. Headscale has a built-in DERP server that you enable with a config block, and the relay map is sent to clients automatically. I run it alongside Tailscale's public relays, so peers get a relay close to home with fallbacks elsewhere. The relay only forwards encrypted packets, so even as the operator you can't read the traffic.

## The bug that ate a weekend

When mesh routing misbehaves, suspect the client before your own config. I lost hours to a macOS Tailscale bug where Headscale accepted subnet routes advertised by a Mac but didn't re-propagate them after reconnects. These are the commands I used to track it down:

```bash
headscale nodes list          # enrollment + last-seen
tailscale ping <node>         # coordination-layer reachability
tailscale ping --tsmp <node>  # protocol-level connectivity
ip route show table 52        # what routes actually got installed
watch -n 0.5 tailscale status # direct vs. relayed, live
```

I ended up sidestepping the bug entirely: I stopped using a Mac as a subnet router and had a Linux VM on the same subnet advertise the routes instead. Check the Tailscale GitHub issues before assuming your Headscale config is wrong.

## The ACLs are still off

Headscale supports Tailscale-style ACLs, and I've written a group-based policy for admins, family, and guests, with a locked-down rule for the public endpoint and a `tests` block that checks the rules do what I expect. It isn't enabled yet, so for now the mesh is permissive, and I rely on VLAN firewall rules and my SSO layer to keep things locked down.

For a long time I blamed pfSense for this. It runs on FreeBSD, where Tailscale can't disable SNAT on subnet routes, so I assumed ACLs couldn't see the real source IP. That turned out to be wrong: Tailscale checks ACLs in its packet filter against the sender's tailnet address, before any SNAT happens. I just need to test the policy with real guest and family devices before flipping the switch. SNAT does still mean LAN hosts and pfSense logs see the router's address instead of the real client, and that's a separate tracked issue.

## What you give up compared to managed Tailscale

- **The admin web UI.** You manage everything via `headscale` CLI commands, which is fine for a single-player setup.
- **New features.** New Tailscale client features sometimes take a while to get Headscale support.
- **Funnel.** HAProxy and a Tailscale client on the VPS do the same job, as described above.

## Who should run it

If you already self-host a lot of infrastructure, Headscale only adds one more systemd service and an occasional version upgrade. In exchange, the record of every device you own and when it connects stays with you. If you just want it to work with no maintenance, pay for Tailscale. The free tier is generous and the product is excellent. This whole homelab is about owning the stack, though, so Headscale was an easy choice for me.
