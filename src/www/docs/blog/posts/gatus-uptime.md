---
date: 2026-08-22
comments: true
social:
  cards_layout_options:
    background_image: docs/img/blog/gatus-uptime-card.webp
    background_color: "#00000073"
image: ../../img/blog/gatus-uptime-card.webp
categories:
  - homelab
  - observability
---

# A Status Page Only I Can See: Uptime Monitoring with Gatus

If your monitoring pipeline breaks quietly, nothing alerts you, and that looks exactly like everything being fine. Gatus is my cheap insurance against that: a small uptime monitor that runs independently of my [metrics stack](observability-stack.md). Grafana tells me what the CPU is doing. Gatus tells me whether each service is up or down, at a glance.

<!-- more -->

<figure class="post-hero" markdown>
![Sunrise over a range of mountain peaks](../../img/blog/gatus-uptime.webp){ width="1600" height="900" loading="lazy" }
<figcaption>Photo by me on a recent trip. A status page should feel like this view: everything visible at a glance.</figcaption>
</figure>

## Why a second monitoring system

The metrics pipeline has several moving parts: agents, remote writes, a time-series database, and rule evaluation. If one of those links breaks quietly, no alert fires. You just stop hearing anything, and that looks the same as everything being fine.

Gatus is a cheap way to cover that gap. It's a single container with a YAML config that polls endpoints on a schedule (HTTP status, response body, DNS, TCP, TLS expiry) and renders a simple status page. It stores results in the Postgres I already run, and there's no query language. It doesn't depend on any part of the metrics pipeline, so a broken scrape or a full time-series disk can't hide an outage from it.

## A private status page

Public status pages make sense for products. For a homelab, a page listing every service you run along with its live health is free reconnaissance for anyone who finds it. So the Gatus dashboard sits behind the same SSO as everything else, and Traefik won't route to it without a valid Authelia session.

That creates a problem: most of the services Gatus checks are behind SSO too, so a plain HTTP probe would just see the login redirect. Gatus solves this by being an OIDC client itself. It gets its own token from Authelia and sends it with every probe, so its checks reach the real service.

If the lab is down and I'm away from home, I check the page through the [mesh VPN](self-hosting-tailscale-headscale.md) like any other service.

## Config that stays in sync

Endpoints aren't written into the Gatus config at all. Every service in my homelab has a line in one inventory file, `nodes.yml`, and giving it an `uptime` name generates the check:

```yaml
home_assistant: {subdomain: home, uptime: home assistant}
```

All internal checks share one template:

```yaml
internal-endpoint: &internal
  interval: 10m
  client:
    oauth2:
      token-url: https://auth.example.com/api/oidc/token
      client-id: ${OIDC_CLIENT_ID}
      client-secret: ${OIDC_CLIENT_SECRET}
      scopes: ['authelia.bearer.authz']
  conditions:
    - "[STATUS] == 200"
    - "[RESPONSE_TIME] < 1000"
```

The same list sets which URLs Gatus's Authelia token is valid for, and the deploy fails if the inventory disagrees with the install scripts, so monitoring can't quietly fall out of sync with what's actually deployed. If I rename a domain in `vars.yml`, the checks pick up the change.

There's also a maintenance window on Saturday mornings, which covers the weekly backup run, so planned downtime doesn't show up as an outage.

## What's not done yet

Gatus doesn't send alerts in my setup yet. Wiring it into ntfy, with a failure threshold so a single timeout doesn't page me and a notification when a service recovers, is next on the list. Until then it's a dashboard I check, and alerting comes from the metrics stack.

Certificate expiry is the other gap. Right now one standalone email timer watches it. Adding a `[CERTIFICATE_EXPIRATION]` condition to these checks would give it a second path, which matters because expired certs are one of the most common ways a homelab breaks without anyone noticing.

Gatus keeps its own history in Postgres, and it also exposes results as metrics that the metrics stack scrapes for trend graphs, so each tool sticks to what it does well.

## Where to start

If you run self-hosted services and only have five minutes for monitoring, set up Gatus before anything more elaborate. It's one container and one YAML file, and it's useful immediately. A full observability stack is worth building eventually, but a status page helps from the first day.
