---
draft: true
date: 2026-10-27
comments: true
categories:
  - homelab
  - observability
---

# A Status Page Only I Can See: Uptime Monitoring with Gatus

The [last post](observability-stack.md) covered the metrics stack. This one covers its safety net: Gatus, a small uptime monitor that answers a different question. Grafana tells me *what the CPU is doing*; Gatus tells me *whether the thing is up* — green or red, at a glance, with its own independent alerting.

<!-- more -->

## Why a second monitoring system

The metrics pipeline has several moving parts: agents, remote writes, a time-series database, rule evaluation. If any link quietly breaks, the result isn't an alert — it's *silence*, which looks exactly like health. Classic watching-the-watchers problem.

Gatus is the cheapest possible answer: a single binary with a YAML config that polls endpoints on a schedule — HTTP status, response body, DNS, TCP, TLS expiry — and renders a clean status page. No database, no query language. It shares nothing with the metrics path except the notification server at the very end, so a metrics outage and a Gatus outage are nearly uncorrelated failures.

## A private status page

Public status pages make sense for products. For a homelab, a list of every service you run (with live health!) is reconnaissance you're hosting for free. So the Gatus dashboard sits behind the same SSO as everything else — Traefik won't route to it without a valid Authelia session, and Gatus is also one of the six OIDC clients, so it knows who's logged in natively.

"But then how do you check it when the lab is down from outside?" — through the [mesh VPN](self-hosting-tailscale-headscale.md), same as everything else. If the mesh itself is down, the push notifications already told me.

## Config that stays in sync

Every endpoint definition lives in the same templated config system as the rest of the homelab, so checks reference the same variables as the services they monitor — rename a domain in `vars.yml` and monitoring follows. A parse script even extracts the endpoint list at render time for other configs to reference. Adding a service to monitoring is a few lines:

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

That last condition is doing quiet, important work: every HTTPS check doubles as certificate-expiry monitoring, warning while there's still a week to act. Combined with the vmalert rule and a standalone email timer, cert expiry — the classic silent homelab killer — is watched by three independent systems. Overkill is a feature here; each path has failed me at least once.

## Alerting behavior

State changes fire into the same ntfy pipeline as the metrics alerts, with flap protection via consecutive-failure thresholds — a single timeout doesn't page me, three in a row does. Recovery sends its own notification, which sounds minor but changes how you relate to incidents: you can see "down" on your phone, decide it can wait, and trust that "back up" will arrive on its own.

One design choice worth noting: in this setup Gatus keeps no long-term history — it's for *current* status. For uptime trends, Gatus exposes its results as metrics, which the metrics stack scrapes like anything else. Each tool does the one thing it's good at, and the pipeline glues them together.

## The takeaway

If you run self-hosted services and have five minutes for monitoring, spend them on Gatus before anything fancier: single container, one YAML file, immediate value. The full observability stack earns its keep later; the status page pays rent on day one.
