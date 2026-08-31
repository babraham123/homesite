---
draft: true
date: 2026-11-17
comments: true
categories:
  - homelab
  - debugging
  - networking
---

# When mDNS Breaks Everything: A Cross-VLAN Debugging Story

After a network reconfiguration, Zigbee2MQTT couldn't reach the MQTT broker anymore. Home Assistant entities went stale, automations stopped, and the lights got dumb. The broker was healthy. The firewall rules were right. The problem looked like three different things before it turned out to be two *other* things, stacked.

I [wrote previously](vlans-and-mdns.md) about how VLAN segmentation breaks mDNS discovery and the repeater setup that fixes it. This is the sequel: what debugging that plumbing actually looks like when it fails silently.

<!-- more -->

## The symptom

Zigbee2MQTT logs a connection refusal to the broker it discovers via mDNS (`_mqtt._tcp.local`) — services find each other by advertisement rather than hardcoded IPs, so IP changes don't break configs. Convenient right up until the discovery layer itself breaks, because mDNS failures don't produce errors. They produce *absence*.

## Hypothesis 1: the firewall (wrong)

The services sit on different subnets, so mDNS crosses a boundary — prime suspect. The pfSense rules for UDP/5353 looked correct, but rules-on-paper prove nothing, so: `tcpdump -i eth0 udp port 5353` on the destination. No packets arriving — and none *leaving the source either*. Packets that are never sent can't be blocked. Not the firewall.

That's the first real lesson: with mDNS, start with tcpdump immediately. Three captures — source, boundary, destination — partition the entire problem space in minutes.

## Hypothesis 2: the repeater (half right)

The mdns_repeater service bridges multicast across the boundary. `systemctl status`: running, zero errors. But its config binds to interfaces *by name* — and the network reconfiguration had changed a Linux interface name (`eth0` → `enp2s0`-style predictable naming). The repeater was faithfully listening on an interface that no longer existed, reporting nothing wrong. Config updated, restarted, packets flowing across the boundary. Confirmed by tcpdump.

And discovery *still* failed.

## Hypothesis 3: something is eating the answers

Packets arriving but the application not seeing the service means something between the wire and the app. Then, from `ps aux`: **avahi-daemon**, running unbidden — pulled in as a dependency of some package and started by default, as Debian does.

Avahi is a full mDNS *responder*: it answers queries on its own authority, using its own records — which knew nothing about services on other subnets. Queries were being answered locally with "no such service" before the repeated cross-VLAN responses mattered. Two silent failures, layered: the interface rename broke the transport, and Avahi shadowed the recovery.

```bash
systemctl disable --now avahi-daemon
```

Lights smart again.

## The 20 lines that made it repeatable

Debugging this through Zigbee2MQTT restarts was agony — slow cycle, noisy logs. The fix-forever move was a tiny Node.js probe using the `multicast-dns` package: give it a service type and an interface, it sends one query and prints every response.

```bash
node mdns.js _mqtt._tcp.local eth0
```

Run it from any VLAN to see exactly what's discoverable from there — repeater, firewall, and advertiser each testable in isolation, no production services involved. It lives in the repo's `test/` directory and has paid for itself several times since.

## Lessons

- **After any network change, check interface names first.** Linux renames interfaces for many reasons, and every config that binds by name breaks silently.
- **tcpdump before theories.** Multicast plumbing has no error path; only packet captures tell the truth.
- **Avahi and an mDNS repeater cannot share a host.** Pick one. Audit for Avahi even if you never installed it — *especially* if you never installed it.
- **Discovery-by-mDNS across subnets is fragile by construction.** For infrastructure services I've since moved toward stable DNS names in Unbound; mDNS remains for the consumer gadgets that genuinely need it.

Total elapsed time: one evening. Time it would take now, with the probe script and the method: about ten minutes. That's the trade debugging stories offer — you pay once, in full, up front.
