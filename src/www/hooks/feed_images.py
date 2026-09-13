"""Fix post image URLs in the generated RSS/JSON feeds.

Posts live in docs/blog/posts/ and set `image: ../../img/blog/<slug>-card.webp` in
their front matter. The rss plugin needs that relative path to read the file size,
but then appends it to site_url, producing `https://site/../../img/...`. After the
build, rewrite those URLs to `https://site/img/...`.
"""

import re
from pathlib import Path

FEEDS = ("feed_rss_created.xml", "feed_rss_updated.xml", "feed_json_created.json", "feed_json_updated.json")


def on_post_build(config, **kwargs):
    site_url = (config.get("site_url") or "").rstrip("/")
    if not site_url:
        return
    pattern = re.compile(re.escape(site_url) + r"/(?:\.\./)+")
    for name in FEEDS:
        feed = Path(config["site_dir"]) / name
        if feed.is_file():
            text = feed.read_text(encoding="utf-8")
            feed.write_text(pattern.sub(site_url + "/", text), encoding="utf-8")
