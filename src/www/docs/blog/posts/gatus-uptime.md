---
date: 2026-08-22
comments: true
categories:
  - homelab
  - observability
---

# A Status Page Only I Can See: Uptime Monitoring with Gatus

The [last post](observability-stack.md) covered the metrics stack. This one covers its backup: Gatus, a small uptime monitor. Grafana tells me what the CPU is doing. Gatus tells me whether a service is up or down, at a glance, and it sends its own alerts.

<!-- more -->

## Why a second monitoring system

The metrics pipeline has several moving parts: agents, remote writes, a time-series database, and rule evaluation. If one of those links breaks quietly, no alert fires. You just stop hearing anything, and that looks the same as everything being fine.

Gatus is a cheap way to cover that gap. It's a single binary with a YAML config that polls endpoints on a schedule (HTTP status, response body, DNS, TCP, TLS expiry) and renders a simple status page. There's no database and no query language. The only thing it shares with the metrics path is the notification server at the end, so a metrics outage and a Gatus outage are unlikely to happen at the same time.

## A private status page

Public status pages make sense for products. For a homelab, a page listing every service you run along with its live health is free reconnaissance for anyone who finds it. So the Gatus dashboard sits behind the same SSO as everything else. Traefik won't route to it without a valid Authelia session, and Gatus is also one of the six OIDC clients, so it knows who's logged in.

If the lab is down and I'm away from home, I check the page through the [mesh VPN](self-hosting-tailscale-headscale.md) like any other service. If the mesh itself is down, I'll already have the push notifications.

## Config that stays in sync

Every endpoint definition lives in the same templated config system as the rest of the homelab, so the checks use the same variables as the services they monitor. If I rename a domain in `vars.yml`, monitoring picks up the change. A parse script also extracts the endpoint list at render time so other configs can reference it. Adding a service to monitoring takes a few lines:

```yaml
- name: home-assistant
  url: "https://home.example.com/"
  interval: 2m
  conditions:
    - "[STATUS] == 200"
    - "[CERTIFICATE_EXPIRATION] > 168h"
  alerts:
    - type: ntfy
```

The last condition matters more than it looks. Every HTTPS check also monitors certificate expiry and warns while there's still a week left to fix it. Between that, a vmalert rule, and a standalone email timer, cert expiry is watched by three separate systems. That's probably overkill, but each of those paths has failed me at least once, and expired certs are one of the most common ways a homelab breaks without anyone noticing.

## Alerting behavior

State changes go into the same ntfy pipeline as the metrics alerts. To avoid flapping, an alert only fires after several consecutive failures: one timeout doesn't page me, three in a row does. Recoveries send their own notification. That sounds minor, but it changes how I handle incidents. I can see "down" on my phone, decide it can wait, and know I'll get a "back up" message when it recovers.

In this setup Gatus doesn't keep long-term history. It's only for current status. For uptime trends, Gatus exposes its results as metrics and the metrics stack scrapes them like anything else, so each tool sticks to what it does well.

## Where to start

If you run self-hosted services and only have five minutes for monitoring, set up Gatus before anything more elaborate. It's one container and one YAML file, and it's useful immediately. A full observability stack is worth building eventually, but a status page helps from the first day.
