"""Prints a runtime summary of the packaged catalogue.

Run from the ``fortiq`` app directory::

    python tool/probe_catalogue.py
"""

from __future__ import annotations

import collections
import json
import urllib.parse
from pathlib import Path

CATALOGUE = Path("assets/data/cleared_catalogue.json")


def payload(link: str) -> tuple[int, str] | None:
    query = urllib.parse.parse_qs(urllib.parse.urlparse(link).query)
    value = query.get("id", [""])[0]
    if ":" not in value:
        return None
    parts = value.split(":")
    if len(parts) != 3 or not parts[0].startswith("TH"):
        return None
    try:
        return int(parts[0][2:]), parts[1]
    except ValueError:
        return None


def main() -> None:
    data = json.loads(CATALOGUE.read_text(encoding="utf-8"))
    records = data["bases"]

    villages = collections.Counter()
    levels: dict[str, collections.Counter] = {
        "home": collections.Counter(),
        "builder": collections.Counter(),
        "unknown": collections.Counter(),
    }
    markers = collections.Counter()
    sources = collections.Counter()
    image_hosts = collections.Counter()
    thumbnail_hosts = collections.Counter()
    lighter = 0

    for record in records:
        parsed = payload(record["link"])
        if parsed is None:
            villages["unknown"] += 1
            levels["unknown"][record["town_hall"]] += 1
            continue
        level, marker = parsed
        markers[marker] += 1
        if marker in ("HV", "WB"):
            villages["home"] += 1
            levels["home"][level] += 1
        elif marker in ("BB", "BB2"):
            villages["builder"] += 1
            levels["builder"][level] += 1
        else:
            villages["unknown"] += 1
            levels["unknown"][level] += 1
        sources[record.get("source_id", "?")] += 1
        image_hosts[urllib.parse.urlparse(record["image"]).netloc] += 1
        thumbnail_hosts[urllib.parse.urlparse(record["thumbnail"]).netloc] += 1
        if record["thumbnail"] != record["image"]:
            lighter += 1

    print(f"total={len(records)}")
    print(f"bytes={CATALOGUE.stat().st_size}")
    print(f"villages={dict(villages)}")
    print(f"markers={dict(markers)}")
    print(f"home_levels={dict(sorted(levels['home'].items()))}")
    print(f"builder_levels={dict(sorted(levels['builder'].items()))}")
    print(f"sources={dict(sources)}")
    print(f"lighter_thumbnails={lighter}")
    print("image_hosts:")
    for host, count in image_hosts.most_common():
        print(f"  {host:28} {count}")
    print("thumbnail_hosts:")
    for host, count in thumbnail_hosts.most_common():
        print(f"  {host:28} {count}")


if __name__ == "__main__":
    main()
